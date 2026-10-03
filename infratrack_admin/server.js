import "dotenv/config";
import express from "express";
import path from "node:path";
import { fileURLToPath } from "node:url";
import crypto from "node:crypto";
import mysql from "mysql2/promise";
import multer from "multer";
import fs from "node:fs";
import { spawn } from "node:child_process";
import ffmpegPath from "ffmpeg-static";
import { computeDuplicateMatch, escalateIssueSeverity } from "./automation.js";
import { validateBarangayCoordinates } from "./barangay-boundaries.js";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const app = express();
app.set("trust proxy", process.env.TRUST_PROXY === "true");
const port = Number(process.env.PORT || 3001);
const forceHttps = String(process.env.FORCE_HTTPS || "false").toLowerCase() === "true";
const recaptchaSecret = process.env.RECAPTCHA_SECRET_KEY || "";
const loginAttempts = new Map();
const dbName = process.env.DB_NAME || "infratrack";
const dbConfig = {
  host: process.env.DB_HOST || "127.0.0.1",
  port: Number(process.env.DB_PORT || 3306),
  user: process.env.DB_USER || "root",
  password: process.env.DB_PASSWORD || "",
};
const pool = mysql.createPool({ ...dbConfig, database: dbName, waitForConnections: true, connectionLimit: 10 });
const uploadDirectory = path.join(__dirname, "uploads");
const backupDirectory = path.join(__dirname, "backups");
fs.mkdirSync(uploadDirectory, { recursive: true });
fs.mkdirSync(backupDirectory, { recursive: true });
const upload = multer({
  dest: uploadDirectory,
  limits: { fileSize: 100 * 1024 * 1024 },
  fileFilter: (_req, file, callback) => {
    const isImage = /^image\//.test(file.mimetype);
    const isVideo = /^video\//.test(file.mimetype);
    const isGif = file.mimetype === "image/gif";
    if (isImage || isVideo || isGif) return callback(null, true);
    callback(new Error("Unsupported file type. Please upload an image or video."));
  },
});

const legacyHashPassword = (password) => crypto.createHash("sha256").update(password).digest("hex");
const hashPassword = (password) => {
  const salt = crypto.randomBytes(16).toString("hex");
  const derived = crypto.scryptSync(String(password), salt, 64).toString("hex");
  return `scrypt$${salt}$${derived}`;
};
const verifyPassword = (password, storedHash) => {
  if (!storedHash) return false;
  if (!storedHash.startsWith("scrypt$")) return storedHash === legacyHashPassword(password);
  const [, salt, expected] = storedHash.split("$");
  if (!salt || !expected) return false;
  const expectedBuffer = Buffer.from(expected, "hex");
  if (!expectedBuffer.length) return false;
  const actualBuffer = crypto.scryptSync(String(password), salt, expectedBuffer.length);
  return actualBuffer.length === expectedBuffer.length && crypto.timingSafeEqual(actualBuffer, expectedBuffer);
};
const hashSessionToken = (token) => crypto.createHash("sha256").update(token).digest("hex");
const createSessionToken = () => crypto.randomBytes(32).toString("hex");
const publicId = () => `MT-${new Date().getFullYear()}-${Math.floor(100 + Math.random() * 900)}`;
const publicMediaUrl = (req, filePath) => {
  if (!filePath) return filePath;
  try {
    const parsed = new URL(String(filePath), `${req.protocol}://${req.get("host")}`);
    return `${req.protocol}://${req.get("host")}${parsed.pathname}`;
  } catch {
    return filePath;
  }
};
const csvValue = (value) => `"${String(value ?? "").replaceAll('"', '""')}"`;
function createDatabaseBackup() {
  return new Promise((resolve, reject) => {
    const dumpPath = process.env.MYSQLDUMP_PATH || "mysqldump";
    const filePath = path.join(backupDirectory, `infratrack-${new Date().toISOString().replaceAll(/[:.]/g, "-")}.sql`);
    const args = [`--host=${dbConfig.host}`, `--port=${dbConfig.port}`, `--user=${dbConfig.user}`, `--password=${dbConfig.password}`, "--single-transaction", "--routines", dbName];
    const output = fs.createWriteStream(filePath);
    const dump = spawn(dumpPath, args, { windowsHide: true });
    let errorOutput = "";
    dump.stderr.on("data", (chunk) => { errorOutput += chunk.toString(); });
    dump.on("error", (error) => { output.close(); fs.rm(filePath, { force: true }, () => {}); reject(error); });
    dump.on("close", (code) => {
      output.close();
      if (code !== 0) { fs.rm(filePath, { force: true }, () => {}); return reject(new Error(errorOutput || `mysqldump exited with code ${code}`)); }
      resolve(filePath);
    });
    dump.stdout.pipe(output);
  });
}
function scheduleDatabaseBackups() {
  const hours = Number(process.env.BACKUP_INTERVAL_HOURS || 24);
  if (hours > 0) setInterval(() => createDatabaseBackup().catch((error) => console.error("Scheduled backup failed:", error.message)), hours * 60 * 60 * 1000);
}
const clientIp = (req) => String(process.env.TRUST_PROXY === "true" ? (req.headers["x-forwarded-for"] || req.ip) : (req.ip || req.socket.remoteAddress) || "unknown").split(",")[0].trim();
const isAutomatedUserAgent = (req) => /bot|crawler|spider|scrapy|curl|wget|python-requests|headless/i.test(String(req.get("user-agent") || ""));
async function verifyRecaptcha(token, ip) {
  if (!recaptchaSecret) return { ok: true, configured: false };
  if (!token) return { ok: false, configured: true };
  const response = await fetch("https://www.google.com/recaptcha/api/siteverify", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({ secret: recaptchaSecret, response: token, remoteip: ip }),
  });
  const result = await response.json();
  return { ok: Boolean(result.success) && Number(result.score ?? 1) >= 0.5, configured: true };
}

async function readSystemSettings() {
  const [rows] = await pool.query("SELECT setting_key, setting_value FROM system_settings");
  return Object.fromEntries(rows.map(({ setting_key, setting_value }) => {
    try { return [setting_key, JSON.parse(setting_value)]; } catch { return [setting_key, setting_value]; }
  }));
}

async function queueNotification({ userId, reportId = null, advisoryId = null, type, title, message, channel = "push" }) {
  if (!userId || !title || !message) return null;
  await pool.query(
    "INSERT INTO notifications (user_id, report_id, advisory_id, type, title, message, channel) VALUES (?, ?, ?, ?, ?, ?, ?)",
    [Number(userId), reportId ?? null, advisoryId ?? null, type || "system", title, message, channel],
  );
  return { ok: true };
}

async function dispatchNotification({ channel = "email", recipient, subject, body }) {
  const resolvedChannel = channel || "email";
  const webhook = resolvedChannel === "sms" ? process.env.SMS_NOTIFICATION_WEBHOOK : process.env.EMAIL_NOTIFICATION_WEBHOOK;
  if (webhook) {
    try {
      await fetch(webhook, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ channel: resolvedChannel, recipient, subject, body }),
      });
    } catch (error) {
      console.warn(`Notification webhook failed for ${resolvedChannel}:`, error.message);
    }
    return;
  }
  console.log(`[InfraTrack ${resolvedChannel.toUpperCase()}] ${subject} :: ${recipient ?? "operations"} :: ${body}`);
}

async function notifyIssueStakeholders(report, eventType = "report") {
  const settings = await readSystemSettings();
  if (eventType === "report" && settings.reportAlerts === false) return;
  const [admins] = await pool.query("SELECT id, email, mobile, name FROM users WHERE role IN ('lgu', 'admin') ORDER BY id");
  const subject = eventType === "duplicate" ? `Duplicate issue detected: ${report.public_id || report.id}` : `Priority escalation: ${report.public_id || report.id}`;
  const body = eventType === "duplicate"
    ? `A duplicate report may be related to ${report.public_id || report.id}. Review the issue queue for possible consolidation.`
    : `Issue ${report.public_id || report.id} has escalated to ${report.severity || "Critical"} and requires immediate follow-up.`;

  for (const admin of admins) {
    await queueNotification({
      userId: admin.id,
      reportId: report.id,
      type: eventType === "duplicate" ? "duplicate_issue" : "priority_escalation",
      title: subject,
      message: body,
      channel: "push",
    });

    if (admin.email) await dispatchNotification({ channel: "email", recipient: admin.email, subject, body });
    if (admin.mobile) await dispatchNotification({ channel: "sms", recipient: admin.mobile, subject: subject.slice(0, 100), body });
  }
}

async function evaluateIssueAutomation(report) {
  const reportId = Number(report.id);
  const [existing] = await pool.query("SELECT id, public_id, title, category, location, latitude, longitude, created_at, severity, status FROM reports WHERE id <> ? AND status NOT IN ('Resolved', 'Rejected', 'Archived') ORDER BY created_at DESC LIMIT 200", [reportId]);
  const duplicate = existing.find((candidate) => computeDuplicateMatch(report, candidate));

  if (duplicate) {
    const details = `Matched existing report ${duplicate.public_id || duplicate.id} in the same barangay category.`;
    await pool.query("UPDATE reports SET duplicate_of = ?, duplicate_reason = ? WHERE id = ?", [duplicate.id, details, reportId]);
    await notifyIssueStakeholders({ ...report, public_id: report.public_id || report.id }, "duplicate");
    return { duplicateOf: duplicate.id, escalated: false };
  }

  const ageHours = report.created_at ? (Date.now() - new Date(report.created_at).getTime()) / 3600000 : 0;
  const nextSeverity = escalateIssueSeverity(report.severity, ageHours);
  if (nextSeverity !== report.severity && report.status && !["Resolved", "Rejected", "Archived"].includes(report.status)) {
    await pool.query(
      "UPDATE reports SET severity = ?, escalated_at = COALESCE(escalated_at, CURRENT_TIMESTAMP), due_at = CASE WHEN due_at IS NULL OR due_at > DATE_ADD(CURRENT_TIMESTAMP, INTERVAL 1 DAY) THEN DATE_ADD(CURRENT_TIMESTAMP, INTERVAL 1 DAY) ELSE due_at END WHERE id = ?",
      [nextSeverity, reportId],
    );
    await notifyIssueStakeholders({ ...report, severity: nextSeverity }, "report");
    return { duplicateOf: null, escalated: true, severity: nextSeverity };
  }

  return { duplicateOf: null, escalated: false };
}

async function sweepEscalations() {
  const [rows] = await pool.query("SELECT r.* FROM reports r WHERE r.status NOT IN ('Resolved', 'Rejected', 'Archived') ORDER BY r.created_at DESC");
  for (const report of rows) {
    const ageHours = report.created_at ? (Date.now() - new Date(report.created_at).getTime()) / 3600000 : 0;
    const nextSeverity = escalateIssueSeverity(report.severity, ageHours);
    if (nextSeverity !== report.severity) {
      await pool.query(
        "UPDATE reports SET severity = ?, escalated_at = COALESCE(escalated_at, CURRENT_TIMESTAMP), due_at = CASE WHEN due_at IS NULL OR due_at > DATE_ADD(CURRENT_TIMESTAMP, INTERVAL 1 DAY) THEN DATE_ADD(CURRENT_TIMESTAMP, INTERVAL 1 DAY) ELSE due_at END WHERE id = ?",
        [nextSeverity, report.id],
      );
      await notifyIssueStakeholders({ ...report, severity: nextSeverity }, "report");
    }
  }
}

async function writeAuditLog(req, { actorId = null, action, resourceType = null, resourceId = null, details = null, actor = null }) {
  try {
    let user = actor;
    if (!user && actorId) {
      const [[found]] = await pool.query("SELECT id, name, email, role FROM users WHERE id = ?", [Number(actorId)]);
      user = found;
    }
    await pool.query(
      "INSERT INTO audit_logs (actor_id, actor_name, actor_email, actor_barangay, actor_role, action, resource_type, resource_id, details, ip_address) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
      [user?.id ?? actorId ?? null, user?.name ?? null, user?.email ?? null, user?.barangay ?? null, user?.role ?? null, action, resourceType, resourceId == null ? null : String(resourceId), details ? JSON.stringify({ ...details, userAgent: req.get("user-agent") || null }) : JSON.stringify({ userAgent: req.get("user-agent") || null }), clientIp(req)],
    );
  } catch (error) {
    console.error("Unable to write audit log:", error.message);
  }
}

async function initializeDatabase() {
  const root = await mysql.createConnection(dbConfig);
  await root.query(`CREATE DATABASE IF NOT EXISTS \`${dbName.replace(/[^a-zA-Z0-9_]/g, "") || "infratrack"}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci`);
  await root.end();

  await pool.query(`CREATE TABLE IF NOT EXISTS users (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY, name VARCHAR(160) NOT NULL,
    email VARCHAR(255) NOT NULL UNIQUE, mobile VARCHAR(40), barangay VARCHAR(120),
    password_hash CHAR(64) NOT NULL, role ENUM('resident','admin','lgu','barangay_staff') NOT NULL DEFAULT 'resident',
    standing VARCHAR(30) NOT NULL DEFAULT 'Active', verification VARCHAR(40) NOT NULL DEFAULT 'Pending ID match',
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
  ) ENGINE=InnoDB`);
  await pool.query(`CREATE TABLE IF NOT EXISTS reports (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY, public_id VARCHAR(32) NOT NULL UNIQUE,
    title VARCHAR(255) NOT NULL, description TEXT NOT NULL, category VARCHAR(80) NOT NULL,
    location VARCHAR(255) NOT NULL DEFAULT 'Mati City', latitude DECIMAL(10,7), longitude DECIMAL(10,7),
    severity VARCHAR(30) NOT NULL DEFAULT 'Medium', status VARCHAR(40) NOT NULL DEFAULT 'Reported',
    duplicate_of INT UNSIGNED NULL, duplicate_reason VARCHAR(255) NULL, escalated_at TIMESTAMP NULL,
    reporter_id INT UNSIGNED NULL, assigned_team VARCHAR(160), resolution_note TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP, updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT reports_reporter_fk FOREIGN KEY (reporter_id) REFERENCES users(id) ON DELETE SET NULL
  ) ENGINE=InnoDB`);
  await pool.query("ALTER TABLE reports ADD COLUMN IF NOT EXISTS due_at TIMESTAMP NULL");
  await pool.query("ALTER TABLE reports ADD COLUMN IF NOT EXISTS duplicate_of INT UNSIGNED NULL");
  await pool.query("ALTER TABLE reports ADD COLUMN IF NOT EXISTS duplicate_reason VARCHAR(255) NULL");
  await pool.query("ALTER TABLE reports ADD COLUMN IF NOT EXISTS escalated_at TIMESTAMP NULL");
  await pool.query(`CREATE TABLE IF NOT EXISTS report_events (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY, report_id INT UNSIGNED NOT NULL,
    status VARCHAR(40) NOT NULL, note TEXT, created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT events_report_fk FOREIGN KEY (report_id) REFERENCES reports(id) ON DELETE CASCADE
  ) ENGINE=InnoDB`);
  await pool.query(`CREATE TABLE IF NOT EXISTS media (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY, report_id INT UNSIGNED NOT NULL,
    file_path VARCHAR(500) NOT NULL, media_type VARCHAR(40) NOT NULL,
    CONSTRAINT media_report_fk FOREIGN KEY (report_id) REFERENCES reports(id) ON DELETE CASCADE
  ) ENGINE=InnoDB`);
  await pool.query(`CREATE TABLE IF NOT EXISTS teams (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY, name VARCHAR(160) NOT NULL UNIQUE,
    department VARCHAR(160), contact_phone VARCHAR(40), active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
  ) ENGINE=InnoDB`);
  await pool.query(`CREATE TABLE IF NOT EXISTS report_assignments (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY, report_id INT UNSIGNED NOT NULL,
    team_id INT UNSIGNED NOT NULL, assigned_by INT UNSIGNED NULL, assigned_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    completed_at TIMESTAMP NULL, CONSTRAINT assignments_report_fk FOREIGN KEY (report_id) REFERENCES reports(id) ON DELETE CASCADE,
    CONSTRAINT assignments_team_fk FOREIGN KEY (team_id) REFERENCES teams(id), CONSTRAINT assignments_admin_fk FOREIGN KEY (assigned_by) REFERENCES users(id) ON DELETE SET NULL
  ) ENGINE=InnoDB`);
  await pool.query(`CREATE TABLE IF NOT EXISTS report_comments (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY, report_id INT UNSIGNED NOT NULL,
    author_id INT UNSIGNED NULL, body TEXT NOT NULL, visibility ENUM('public','official','semi-public') NOT NULL DEFAULT 'public',
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP, CONSTRAINT comments_report_fk FOREIGN KEY (report_id) REFERENCES reports(id) ON DELETE CASCADE,
    CONSTRAINT comments_author_fk FOREIGN KEY (author_id) REFERENCES users(id) ON DELETE SET NULL
  ) ENGINE=InnoDB`);
  await pool.query(`CREATE TABLE IF NOT EXISTS report_followers (
    report_id INT UNSIGNED NOT NULL, user_id INT UNSIGNED NOT NULL, followed_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (report_id, user_id), CONSTRAINT followers_report_fk FOREIGN KEY (report_id) REFERENCES reports(id) ON DELETE CASCADE,
    CONSTRAINT followers_user_fk FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
  ) ENGINE=InnoDB`);
  await pool.query(`CREATE TABLE IF NOT EXISTS report_ratings (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY, report_id INT UNSIGNED NOT NULL, user_id INT UNSIGNED NOT NULL,
    rating TINYINT UNSIGNED NOT NULL, comment TEXT, created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY one_rating_per_user (report_id, user_id), CONSTRAINT ratings_report_fk FOREIGN KEY (report_id) REFERENCES reports(id) ON DELETE CASCADE,
    CONSTRAINT ratings_user_fk FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
  ) ENGINE=InnoDB`);
  await pool.query(`CREATE TABLE IF NOT EXISTS advisories (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY, type VARCHAR(30) NOT NULL DEFAULT 'gen', title VARCHAR(255) NOT NULL,
    message TEXT NOT NULL, audience VARCHAR(120) NOT NULL DEFAULT 'All barangays', status ENUM('draft','published','archived') NOT NULL DEFAULT 'published',
    created_by INT UNSIGNED NULL, published_at TIMESTAMP NULL, created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP, updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT advisories_author_fk FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE SET NULL
  ) ENGINE=InnoDB`);
  await pool.query(`CREATE TABLE IF NOT EXISTS advisory_media (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY, advisory_id INT UNSIGNED NOT NULL,
    file_path VARCHAR(500) NOT NULL, media_type VARCHAR(40) NOT NULL, CONSTRAINT advisory_media_fk FOREIGN KEY (advisory_id) REFERENCES advisories(id) ON DELETE CASCADE
  ) ENGINE=InnoDB`);
  await pool.query("ALTER TABLE advisories ADD COLUMN IF NOT EXISTS barangay VARCHAR(120) NULL");
  await pool.query(`CREATE TABLE IF NOT EXISTS notifications (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY, user_id INT UNSIGNED NOT NULL, report_id INT UNSIGNED NULL, advisory_id INT UNSIGNED NULL,
    type VARCHAR(50) NOT NULL, title VARCHAR(255) NOT NULL, message TEXT NOT NULL, channel VARCHAR(30) NOT NULL DEFAULT 'push', read_at TIMESTAMP NULL, created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT notifications_user_fk FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE, CONSTRAINT notifications_report_fk FOREIGN KEY (report_id) REFERENCES reports(id) ON DELETE CASCADE,
    CONSTRAINT notifications_advisory_fk FOREIGN KEY (advisory_id) REFERENCES advisories(id) ON DELETE CASCADE
  ) ENGINE=InnoDB`);
  await pool.query("ALTER TABLE notifications ADD COLUMN IF NOT EXISTS channel VARCHAR(30) NOT NULL DEFAULT 'push'");
  await pool.query(`CREATE TABLE IF NOT EXISTS user_preferences (
    user_id INT UNSIGNED PRIMARY KEY, allow_notifications BOOLEAN NOT NULL DEFAULT TRUE, show_location_on_reports BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP, CONSTRAINT preferences_user_fk FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
  ) ENGINE=InnoDB`);
  await pool.query(`CREATE TABLE IF NOT EXISTS verification_documents (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY, user_id INT UNSIGNED NOT NULL, document_type VARCHAR(60) NOT NULL,
    file_path VARCHAR(500), status ENUM('pending','approved','rejected') NOT NULL DEFAULT 'pending', reviewed_by INT UNSIGNED NULL,
    reviewed_at TIMESTAMP NULL, created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP, CONSTRAINT verification_user_fk FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    CONSTRAINT verification_reviewer_fk FOREIGN KEY (reviewed_by) REFERENCES users(id) ON DELETE SET NULL
  ) ENGINE=InnoDB`);
  await pool.query(`CREATE TABLE IF NOT EXISTS moderation_actions (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY, user_id INT UNSIGNED NOT NULL, admin_id INT UNSIGNED NULL,
    action ENUM('warn','suspend','ban','restore') NOT NULL, reason VARCHAR(160) NOT NULL,
    duration VARCHAR(40), note TEXT, created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT moderation_user_fk FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    CONSTRAINT moderation_admin_fk FOREIGN KEY (admin_id) REFERENCES users(id) ON DELETE SET NULL
  ) ENGINE=InnoDB`);
  await pool.query(`CREATE TABLE IF NOT EXISTS audit_logs (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    actor_id INT UNSIGNED NULL, actor_name VARCHAR(160), actor_email VARCHAR(255), actor_barangay VARCHAR(120),
    actor_role VARCHAR(40), action VARCHAR(80) NOT NULL, resource_type VARCHAR(80),
    resource_id VARCHAR(120), details TEXT, ip_address VARCHAR(64),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX audit_created_idx (created_at), INDEX audit_actor_idx (actor_id),
    CONSTRAINT audit_actor_fk FOREIGN KEY (actor_id) REFERENCES users(id) ON DELETE SET NULL
  ) ENGINE=InnoDB`);
  await pool.query(`CREATE TABLE IF NOT EXISTS admin_sessions (
    token_hash CHAR(64) PRIMARY KEY, user_id INT UNSIGNED NOT NULL,
    expires_at TIMESTAMP NOT NULL, created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX sessions_expiry_idx (expires_at),
    CONSTRAINT sessions_user_fk FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
  ) ENGINE=InnoDB`);
  await pool.query("ALTER TABLE audit_logs ADD COLUMN IF NOT EXISTS actor_barangay VARCHAR(120) AFTER actor_email");
  await pool.query("UPDATE audit_logs a JOIN users u ON u.id = a.actor_id SET a.actor_barangay = u.barangay WHERE a.actor_barangay IS NULL");
  await pool.query(`CREATE TABLE IF NOT EXISTS system_settings (
    setting_key VARCHAR(80) PRIMARY KEY, setting_value TEXT NOT NULL,
    updated_by INT UNSIGNED NULL, updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT settings_updated_by_fk FOREIGN KEY (updated_by) REFERENCES users(id) ON DELETE SET NULL
  ) ENGINE=InnoDB`);
  await pool.query("ALTER TABLE users MODIFY role ENUM('resident','admin','lgu','barangay_staff') NOT NULL DEFAULT 'resident'");
  await pool.query("UPDATE users SET role = 'lgu' WHERE role = 'admin'");
  await pool.query("UPDATE reports SET latitude = 6.8993278, longitude = 126.1510600 WHERE location = 'Brgy. Dawan'");
  await pool.query("UPDATE reports SET due_at = DATE_ADD(created_at, INTERVAL 3 DAY) WHERE due_at IS NULL");

  const [[count]] = await pool.query("SELECT COUNT(*) AS count FROM users");
  if (Number(count.count) > 0) return;
  const insertUser = "INSERT INTO users (name, email, mobile, barangay, password_hash, role, verification) VALUES (?, ?, ?, ?, ?, ?, ?)";
  const residents = [["Elena Marasigan", "elena.m@example.com", "Brgy. Central"], ["Marco Bantilan", "marco.b@example.com", "Brgy. Dawan"], ["Grace Villareal", "grace.v@example.com", "Brgy. Central"], ["Rico Fernandez", "rico.f@example.com", "Brgy. Sainz"]];
  for (const [name, email, barangay] of residents) await pool.query(insertUser, [name, email, "", barangay, hashPassword("Mati2026!"), "resident", "Verified"]);
  await pool.query(insertUser, ["City Administrator", "admin@infratrack.test", "", "Mati City", hashPassword("Mati2026!"), "lgu", "Verified"]);
  const reports = [
    ["MT-2026-881", "Deep pothole along Rizal St.", "Road surface damage reported by a resident.", "Roads", "Brgy. Central", 6.953, 126.228, "Critical", "Reported", "elena.m@example.com"],
    ["MT-2026-879", "No water supply, Purok 3", "Residents report a broken main line.", "Water", "Brgy. Dawan", 6.9482, 126.2311, "High", "In progress", "marco.b@example.com"],
    ["MT-2026-884", "Clogged drainage near market", "Drainage blockage near the public market.", "Drainage", "Brgy. Central", 6.9511, 126.2249, "Medium", "Reported", "grace.v@example.com"],
    ["MT-2026-860", "Streetlight repaired, J.P. Laurel", "Streetlight repair completed.", "Lighting", "Brgy. Sainz", 6.9498, 126.2295, "Low", "Resolved", "rico.f@example.com"],
  ];
  for (const [id, title, description, category, location, lat, lng, severity, status, email] of reports) {
    const [[user]] = await pool.query("SELECT id FROM users WHERE email = ?", [email]);
    const [result] = await pool.query("INSERT INTO reports (public_id, title, description, category, location, latitude, longitude, severity, status, reporter_id) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)", [id, title, description, category, location, lat, lng, severity, status, user.id]);
    await pool.query("INSERT INTO report_events (report_id, status, note) VALUES (?, ?, ?)", [result.insertId, status, description]);
  }
}

async function seedAdvisories() {
  const [[count]] = await pool.query("SELECT COUNT(*) AS count FROM advisories");
  if (Number(count.count) > 0) return;
  const [[admin]] = await pool.query("SELECT id FROM users WHERE role IN ('lgu', 'admin') ORDER BY id LIMIT 1");
  if (!admin) return;
  const samples = [
    ["alert", "Flash flood advisory for low-lying barangays", "Heavy rainfall expected through tonight. Residents near Mati River are advised to move valuables to higher ground."],
    ["maint", "Water interruption, Barangay Central", "Scheduled pipe repair will suspend water supply from 1:00 PM to 6:00 PM today."],
    ["gen", "Road resurfacing begins on Rizal Street", "Expect single-lane traffic near the public market from Monday. Motorists are asked to use the Chapel Street alternate."],
    ["gen", "Report follow-up: J.P. Laurel streetlight", "Repair crew completed replacement of 4 damaged fixtures reported by residents this week."],
  ];
  for (const [type, title, message] of samples) {
    await pool.query("INSERT INTO advisories (type, title, message, created_by, published_at) VALUES (?, ?, ?, ?, CURRENT_TIMESTAMP)", [type, title, message, admin.id]);
  }
}

async function ensureDefaultStaffAccount() {
  const staffAccounts = [
    ["Barangay Central Staff", "staff.central@infratrack.test", "Brgy. Central"],
    ["Barangay Dawan Staff", "staff.dawan@infratrack.test", "Brgy. Dawan"],
    ["Barangay Sainz Staff", "staff.sainz@infratrack.test", "Brgy. Sainz"],
    ["Barangay Matiao Staff", "staff.matiao@infratrack.test", "Brgy. Matiao"],
    ["Barangay Dahican Staff", "staff.dahican@infratrack.test", "Brgy. Dahican"],
  ];
  for (const [name, email, barangay] of staffAccounts) {
    await pool.query(
      "INSERT IGNORE INTO users (name, email, mobile, barangay, password_hash, role, verification) VALUES (?, ?, ?, ?, ?, ?, ?)",
      [name, email, "", barangay, hashPassword("Mati2026!"), "barangay_staff", "Verified"],
    );
  }
}
async function ensureDefaultTeams() {
  const teams = [["Roads Response Team", "Roads"], ["Water Services Team", "Water"], ["Drainage Crew", "Drainage"], ["Lighting Unit", "Lighting"]];
  for (const [name, department] of teams) await pool.query("INSERT IGNORE INTO teams (name, department) VALUES (?, ?)", [name, department]);
}

app.use(express.json());
app.use((req, res, next) => {
  const forwardedProto = String(req.headers["x-forwarded-proto"] || "").split(",")[0].trim().toLowerCase();
  const host = String(req.headers.host || "");
  const isSecure = req.secure || forwardedProto === "https";
  const isLocalhost = /^(localhost|127\.0\.0\.1|\[::1\])(?::\d+)?$/i.test(host) || req.hostname === "localhost";
  if (forceHttps && !isLocalhost && !isSecure) {
    return res.redirect(301, `https://${host}${req.originalUrl}`);
  }
  if (req.path.startsWith("/api/")) {
    res.header("Cache-Control", "no-store, no-cache, must-revalidate, private");
  } else if (req.path.startsWith("/uploads/")) {
    res.header("Cache-Control", "public, max-age=3600, stale-while-revalidate=86400");
  }
  res.header("Access-Control-Allow-Origin", "*");
  res.header("Access-Control-Allow-Headers", "Content-Type, Authorization");
  res.header("Access-Control-Allow-Methods", "GET, POST, PATCH, OPTIONS");
  if (req.method === "OPTIONS") return res.sendStatus(204);
  next();
});
app.use(async (req, res, next) => {
  if (
    !req.path.startsWith("/api/") ||
    req.path === "/api/health" ||
    req.path === "/api/auth/login" ||
    req.path === "/api/auth/register"
  ) return next();
  // Residents submit and view their reports from the mobile app without an admin session.
  if (req.path === "/api/reports" && ["GET", "POST"].includes(req.method)) return next();
  const token = String(req.headers.authorization || "").replace(/^Bearer\s+/i, "");
  if (!token) return res.status(401).json({ error: "Authentication required" });
  const [[user]] = await pool.query(
    "SELECT u.id, u.name, u.email, u.barangay, u.role FROM admin_sessions s JOIN users u ON u.id = s.user_id WHERE s.token_hash = ? AND s.expires_at > CURRENT_TIMESTAMP",
    [hashSessionToken(token)],
  );
  if (!user || !["lgu", "admin", "barangay_staff"].includes(user.role)) return res.status(401).json({ error: "Session expired or invalid" });
  req.auth = user;
  next();
});
app.use("/uploads", express.static(uploadDirectory, { maxAge: "1h", etag: true }));
app.get("/api/health", async (_req, res) => {
  try { await pool.query("SELECT 1"); res.json({ ok: true, service: "InfraTrack Admin API", database: dbName }); }
  catch { res.status(503).json({ ok: false, error: "Database unavailable" }); }
});
app.post("/api/auth/login", async (req, res) => {
  const { email, password, recaptchaToken } = req.body ?? {};
  const ip = clientIp(req);
  const now = Date.now();
  const attempt = loginAttempts.get(ip) || { count: 0, resetAt: now + 15 * 60 * 1000 };
  if (now > attempt.resetAt) { attempt.count = 0; attempt.resetAt = now + 15 * 60 * 1000; }
  if (attempt.count >= 10 || isAutomatedUserAgent(req)) {
    await writeAuditLog(req, { action: "login_blocked", resourceType: "authentication", details: { reason: isAutomatedUserAgent(req) ? "automated_user_agent" : "rate_limit", email: String(email ?? "").trim() } });
    return res.status(429).json({ error: "Too many or automated login attempts. Please try again later." });
  }
  const captcha = await verifyRecaptcha(recaptchaToken, ip);
  if (!captcha.ok) {
    attempt.count += 1;
    loginAttempts.set(ip, attempt);
    await writeAuditLog(req, { action: "login_blocked", resourceType: "authentication", details: { reason: "recaptcha_failed", email: String(email ?? "").trim() } });
    return res.status(403).json({ error: "Security verification failed. Please try again." });
  }
  attempt.count += 1;
  loginAttempts.set(ip, attempt);
  const [rows] = await pool.query("SELECT * FROM users WHERE email = ?", [String(email ?? "").trim()]);
  const user = rows[0];
  if (!user || !verifyPassword(String(password ?? ""), user.password_hash)) {
    await writeAuditLog(req, { action: "login_failed", resourceType: "authentication", details: { email: String(email ?? "").trim() }, actor: user ? { ...user, role: user.role } : { email: String(email ?? "").trim() } });
    return res.status(401).json({ error: "Invalid email or password" });
  }
  loginAttempts.delete(ip);
  if (!user.password_hash.startsWith("scrypt$")) {
    await pool.query("UPDATE users SET password_hash = ? WHERE id = ?", [hashPassword(String(password ?? "")), user.id]);
  }
  const sessionToken = createSessionToken();
  await pool.query("INSERT INTO admin_sessions (token_hash, user_id, expires_at) VALUES (?, ?, DATE_ADD(CURRENT_TIMESTAMP, INTERVAL 8 HOUR))", [hashSessionToken(sessionToken), user.id]);
  await writeAuditLog(req, { action: "login", resourceType: "authentication", actor: user });
  res.json({ token: sessionToken, user: { id: user.id, name: user.name, email: user.email, barangay: user.barangay, role: user.role } });
});
app.post("/api/auth/logout", async (req, res) => {
  const token = String(req.headers.authorization || "").replace(/^Bearer\s+/i, "");
  if (token) await pool.query("DELETE FROM admin_sessions WHERE token_hash = ?", [hashSessionToken(token)]);
  res.status(204).end();
});
app.patch("/api/account/password", async (req, res) => {
  const { currentPassword, newPassword } = req.body ?? {};
  if (!currentPassword || !newPassword || String(newPassword).length < 8) return res.status(400).json({ error: "New password must be at least 8 characters" });
  const [[user]] = await pool.query("SELECT id, password_hash FROM users WHERE id = ?", [req.auth.id]);
  if (!user || !verifyPassword(String(currentPassword), user.password_hash)) return res.status(400).json({ error: "Current password is incorrect" });
  await pool.query("UPDATE users SET password_hash = ? WHERE id = ?", [hashPassword(String(newPassword)), user.id]);
  await writeAuditLog(req, { actorId: user.id, action: "password_changed", resourceType: "account", resourceId: user.id });
  res.json({ ok: true });
});
app.get("/api/audit-logs", async (req, res) => {
  const admin = req.auth;
  if (!admin || !["lgu", "admin", "barangay_staff"].includes(admin.role)) return res.status(403).json({ error: "Administrator access required" });
  const limit = Math.min(Math.max(Number(req.query.limit) || 100, 1), 500);
  const conditions = [];
  const params = [];
  if (admin.role === "barangay_staff") { conditions.push("actor_barangay = ?"); params.push(admin.barangay); }
  if (req.query.user) { conditions.push("(actor_name LIKE ? OR actor_email LIKE ?)"); params.push(`%${req.query.user}%`, `%${req.query.user}%`); }
  if (req.query.action) { conditions.push("action = ?"); params.push(String(req.query.action)); }
  if (req.query.barangay && admin.role !== "barangay_staff") { conditions.push("actor_barangay = ?"); params.push(String(req.query.barangay)); }
  if (req.query.from) { conditions.push("created_at >= ?"); params.push(`${req.query.from} 00:00:00`); }
  if (req.query.to) { conditions.push("created_at <= ?"); params.push(`${req.query.to} 23:59:59`); }
  const logScope = conditions.length ? ` WHERE ${conditions.join(" AND ")}` : "";
  params.push(limit);
  const [logs] = await pool.query(
    `SELECT id, actor_id, actor_name, actor_email, actor_barangay, actor_role, action, resource_type, resource_id, details, ip_address, created_at FROM audit_logs${logScope} ORDER BY created_at DESC LIMIT ?`,
    params,
  );
  res.json({ logs });
});
app.get("/api/settings", async (req, res) => {
  const viewer = req.auth;
  if (!viewer || !["lgu", "admin", "barangay_staff"].includes(viewer.role)) return res.status(403).json({ error: "Administrator access required" });
  const [rows] = await pool.query("SELECT setting_key, setting_value FROM system_settings");
  const settings = Object.fromEntries(rows.map(({ setting_key, setting_value }) => {
    try { return [setting_key, JSON.parse(setting_value)]; } catch { return [setting_key, setting_value]; }
  }));
  res.json({ settings });
});
app.patch("/api/settings", async (req, res) => {
  const { settings = {} } = req.body ?? {};
  const viewer = req.auth;
  if (!viewer || !["lgu", "admin", "barangay_staff"].includes(viewer.role)) return res.status(403).json({ error: "Administrator access required" });
  const allowed = ["liveNotifications", "emailDigest", "autoAssign", "requireApproval", "reportAlerts", "publicAdvisoryAlerts"];
  for (const key of allowed) {
    if (typeof settings[key] === "boolean") {
      await pool.query("INSERT INTO system_settings (setting_key, setting_value, updated_by) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE setting_value = VALUES(setting_value), updated_by = VALUES(updated_by)", [key, JSON.stringify(settings[key]), viewer.id]);
    }
  }
  await writeAuditLog(req, { actorId: viewer.id, action: "settings_updated", resourceType: "system_settings", details: settings });
  res.json({ ok: true, settings });
});
app.post("/api/admin/backup", async (req, res) => {
  if (!["lgu", "admin"].includes(req.auth.role)) return res.status(403).json({ error: "LGU administrator access required" });
  try {
    const filePath = await createDatabaseBackup();
    await writeAuditLog(req, { actorId: req.auth.id, action: "database_backup_created", resourceType: "database", details: { file: path.basename(filePath) } });
    res.download(filePath, path.basename(filePath));
  } catch (error) {
    res.status(503).json({ error: `Backup failed: ${error.message}` });
  }
});
app.get("/api/admin/export/:type", async (req, res) => {
  if (!["lgu", "admin", "barangay_staff"].includes(req.auth.role)) return res.status(403).json({ error: "Administrator access required" });
  if (!["issues", "users"].includes(req.params.type)) return res.status(400).json({ error: "Unsupported export type" });
  const scope = req.auth.role === "barangay_staff" ? " WHERE r.location = ?" : "";
  const params = scope ? [req.auth.barangay] : [];
  const [rows] = req.params.type === "issues"
    ? await pool.query(`SELECT r.public_id, r.title, r.category, r.location, r.severity, r.status, u.name AS reporter, r.created_at FROM reports r LEFT JOIN users u ON u.id = r.reporter_id${scope} ORDER BY r.created_at DESC`, params)
    : await pool.query(`SELECT u.name, u.email, u.barangay, u.standing, u.verification, u.created_at FROM users u WHERE u.role = 'resident'${req.auth.role === "barangay_staff" ? " AND u.barangay = ?" : ""} ORDER BY u.created_at DESC`, params);
  const headers = req.params.type === "issues" ? ["Public ID", "Title", "Category", "Barangay", "Severity", "Status", "Reporter", "Created"] : ["Name", "Email", "Barangay", "Standing", "Verification", "Created"];
  const values = rows.map((row) => Object.values(row).map(csvValue).join(","));
  await writeAuditLog(req, { actorId: req.auth.id, action: `export_${req.params.type}`, resourceType: req.params.type, details: { count: rows.length } });
  res.type("text/csv").set("Content-Disposition", `attachment; filename=infratrack-${req.params.type}.csv`).send([headers.map(csvValue).join(","), ...values].join("\n"));
});
app.post("/api/auth/register", async (req, res) => {
  const { name, email, mobile, barangay, password } = req.body ?? {};
  if (!name || !email || !password) return res.status(400).json({ error: "Name, email, and password are required" });
  try {
    const [result] = await pool.query("INSERT INTO users (name, email, mobile, barangay, password_hash) VALUES (?, ?, ?, ?, ?)", [name.trim(), email.trim().toLowerCase(), mobile ?? "", barangay ?? "Mati City", hashPassword(password)]);
    res.status(201).json({ user: { id: result.insertId, name, email, barangay, role: "resident" } });
  } catch (error) {
    if (error.code === "ER_DUP_ENTRY") return res.status(409).json({ error: "An account with this email already exists" });
    res.status(500).json({ error: "Could not create account" });
  }
});
app.get("/api/issues", async (req, res) => {
  const search = `%${String(req.query.search ?? "").toLowerCase()}%`;
  const viewer = req.auth;
  const barangayFilter = viewer?.role === "barangay_staff" ? " AND r.location = ?" : "";
  const [issues] = await pool.query(`SELECT r.*, u.name AS reporter FROM reports r LEFT JOIN users u ON u.id = r.reporter_id WHERE r.status <> 'Archived' AND LOWER(CONCAT(r.title, ' ', r.location, ' ', r.public_id)) LIKE ?${barangayFilter} ORDER BY r.created_at DESC`, barangayFilter ? [search, viewer.barangay] : [search]);
  res.json({ issues });
});
app.get("/api/overview", async (req, res) => {
  const viewer = req.auth;
  const scope = viewer?.role === "barangay_staff" ? " AND location = ?" : "";
  const scopeParams = scope ? [viewer.barangay] : [];
  const [[summary]] = await pool.query(`SELECT COUNT(*) AS total,
    SUM(status IN ('Reported', 'Verified by inspector')) AS pending,
    SUM(status = 'Resolved') AS resolved,
    ROUND(AVG(CASE WHEN status = 'Resolved' THEN TIMESTAMPDIFF(HOUR, created_at, updated_at) / 24 END), 1) AS avg_resolution_days
    FROM reports WHERE 1=1${scope}`, scopeParams);
  const [[categoriesTotal]] = await pool.query(`SELECT COUNT(*) AS total FROM reports WHERE 1=1${scope}`, scopeParams);
  const [categories] = await pool.query(`SELECT category AS name, COUNT(*) AS count FROM reports WHERE 1=1${scope} GROUP BY category ORDER BY count DESC`, scopeParams);
  const [teams] = await pool.query(`SELECT COALESCE(NULLIF(assigned_team, ''), 'Unassigned') AS name,
    COUNT(*) AS active_count, MAX(location) AS location FROM reports
    WHERE status <> 'Resolved'${scope} GROUP BY COALESCE(NULLIF(assigned_team, ''), 'Unassigned') ORDER BY active_count DESC LIMIT 6`, scopeParams);
  const [recent] = await pool.query(`SELECT public_id, title, status, category, location, created_at
    FROM reports WHERE 1=1${scope} ORDER BY created_at DESC LIMIT 5`, scopeParams);
  res.json({
    summary: { total: Number(summary.total || 0), pending: Number(summary.pending || 0), resolved: Number(summary.resolved || 0), avgResolutionDays: Number(summary.avg_resolution_days || 0), completionRate: summary.total ? Math.round((Number(summary.resolved || 0) / Number(summary.total)) * 100) : 0 },
    categories: categories.map((item) => ({ name: item.name, count: Number(item.count), percentage: categoriesTotal.total ? Math.round((Number(item.count) / Number(categoriesTotal.total)) * 100) : 0 })),
    teams: teams.map((item) => ({ name: item.name, activeCount: Number(item.active_count), location: item.location })),
    recent,
  });
});
app.get("/api/analytics", async (req, res) => {
  const period = ["day", "week", "month", "year"].includes(req.query.period) ? req.query.period : "month";
  const settings = {
    day: { interval: "1 DAY", format: "%Y-%m-%d %H:00", label: "Day" },
    week: { interval: "7 DAY", format: "%Y-%m-%d", label: "Week" },
    month: { interval: "1 MONTH", format: "%Y-%m-%d", label: "Month" },
    year: { interval: "1 YEAR", format: "%Y-%m", label: "Year" },
  }[period];
  const viewer = req.auth;
  const where = `created_at >= DATE_SUB(NOW(), INTERVAL ${settings.interval})${viewer?.role === "barangay_staff" ? " AND location = ?" : ""}`;
  const whereParams = viewer?.role === "barangay_staff" ? [viewer.barangay] : [];
  const [[summary]] = await pool.query(`SELECT COUNT(*) AS total,
    SUM(status = 'Reported') AS reported, SUM(status = 'In progress') AS in_progress,
    SUM(status = 'Resolved') AS resolved FROM reports WHERE ${where}`, whereParams);
  const [categories] = await pool.query(`SELECT category AS name, COUNT(*) AS count FROM reports WHERE ${where} GROUP BY category ORDER BY count DESC`, whereParams);
  const [hotspots] = await pool.query(`SELECT location AS name, category, COUNT(*) AS count FROM reports WHERE ${where} GROUP BY location, category ORDER BY count DESC LIMIT 5`, whereParams);
  const [trend] = await pool.query(`SELECT DATE_FORMAT(created_at, ?) AS label, COUNT(*) AS count FROM reports WHERE ${where} GROUP BY label ORDER BY label`, [settings.format, ...whereParams]);
  const ratingsWhere = where.replaceAll("created_at", "r.created_at").replaceAll("location", "r.location");
  const [[ratings]] = await pool.query(`SELECT ROUND(AVG(rating), 1) AS average, COUNT(*) AS total FROM report_ratings rr JOIN reports r ON r.id = rr.report_id WHERE ${ratingsWhere}`, whereParams);
  res.json({ period, periodLabel: settings.label, summary: { total: Number(summary.total || 0), reported: Number(summary.reported || 0), inProgress: Number(summary.in_progress || 0), resolved: Number(summary.resolved || 0) }, categories, hotspots, trend, ratings: { average: Number(ratings.average || 0), total: Number(ratings.total || 0) } });
});
app.get("/api/users", async (req, res) => {
  const viewer = req.auth;
  const barangayFilter = viewer?.role === "barangay_staff" ? " AND u.barangay = ?" : "";
  const [users] = await pool.query(`SELECT u.id, u.name, u.email, u.barangay, u.standing, u.verification, DATE_FORMAT(u.created_at, '%b %Y') AS joined, COUNT(r.id) AS reports FROM users u LEFT JOIN reports r ON r.reporter_id = u.id WHERE u.role = 'resident'${barangayFilter} GROUP BY u.id ORDER BY u.created_at DESC`, barangayFilter ? [viewer.barangay] : []);
  res.json({ users });
});
app.get("/api/teams", async (req, res) => {
  const [teams] = await pool.query("SELECT id, name, department, contact_phone, active FROM teams WHERE active = TRUE ORDER BY name");
  res.json({ teams });
});
app.post("/api/teams", async (req, res) => {
  if (!["lgu", "admin"].includes(req.auth.role)) return res.status(403).json({ error: "LGU administrator access required" });
  const { name, department = "", contactPhone = "" } = req.body ?? {};
  if (!name?.trim()) return res.status(400).json({ error: "Team name is required" });
  try {
    const [result] = await pool.query("INSERT INTO teams (name, department, contact_phone) VALUES (?, ?, ?)", [name.trim(), department.trim(), contactPhone.trim()]);
    await writeAuditLog(req, { actorId: req.auth.id, action: "team_created", resourceType: "team", resourceId: result.insertId, details: { name: name.trim(), department } });
    res.status(201).json({ team: { id: result.insertId, name: name.trim(), department, contact_phone: contactPhone, active: 1 } });
  } catch (error) { if (error.code === "ER_DUP_ENTRY") return res.status(409).json({ error: "A team with this name already exists" }); throw error; }
});
app.get("/api/staff", async (req, res) => {
  if (!["lgu", "admin"].includes(req.auth.role)) return res.status(403).json({ error: "LGU administrator access required" });
  const [staff] = await pool.query("SELECT id, name, email, barangay, role, standing, verification, DATE_FORMAT(created_at, '%b %Y') AS joined FROM users WHERE role IN ('barangay_staff', 'lgu', 'admin') ORDER BY role, name");
  res.json({ staff });
});
app.post("/api/staff", async (req, res) => {
  if (!["lgu", "admin"].includes(req.auth.role)) return res.status(403).json({ error: "LGU administrator access required" });
  const { name, email, barangay, password, role = "barangay_staff" } = req.body ?? {};
  if (!name?.trim() || !email?.trim() || !barangay?.trim() || !password || password.length < 8) return res.status(400).json({ error: "Name, email, barangay, and an 8-character password are required" });
  if (!["barangay_staff", "lgu"].includes(role)) return res.status(400).json({ error: "Invalid staff role" });
  try {
    const [result] = await pool.query("INSERT INTO users (name, email, barangay, password_hash, role, standing, verification) VALUES (?, ?, ?, ?, ?, 'Active', 'Verified')", [name.trim(), email.trim().toLowerCase(), barangay.trim(), hashPassword(password), role]);
    await writeAuditLog(req, { actorId: req.auth.id, action: "staff_created", resourceType: "user", resourceId: result.insertId, details: { email: email.trim().toLowerCase(), barangay: barangay.trim(), role } });
    res.status(201).json({ staff: { id: result.insertId, name: name.trim(), email: email.trim().toLowerCase(), barangay: barangay.trim(), role, standing: "Active" } });
  } catch (error) {
    if (error.code === "ER_DUP_ENTRY") return res.status(409).json({ error: "An account with this email already exists" });
    res.status(500).json({ error: "Could not create staff account" });
  }
});
app.patch("/api/staff/:id", async (req, res) => {
  if (!["lgu", "admin"].includes(req.auth.role)) return res.status(403).json({ error: "LGU administrator access required" });
  const { name, email, barangay, standing, role, password } = req.body ?? {};
  const [rows] = await pool.query("SELECT id, role FROM users WHERE id = ? AND role IN ('barangay_staff', 'lgu', 'admin')", [Number(req.params.id)]);
  if (!rows[0]) return res.status(404).json({ error: "Staff account not found" });
  if (role && !["barangay_staff", "lgu"].includes(role)) return res.status(400).json({ error: "Invalid staff role" });
  await pool.query("UPDATE users SET name = COALESCE(?, name), email = COALESCE(?, email), barangay = COALESCE(?, barangay), standing = COALESCE(?, standing), role = COALESCE(?, role), password_hash = COALESCE(?, password_hash) WHERE id = ?", [name?.trim() || null, email?.trim().toLowerCase() || null, barangay?.trim() || null, standing || null, role || null, password && password.length >= 8 ? hashPassword(password) : null, Number(req.params.id)]);
  await writeAuditLog(req, { actorId: req.auth.id, action: password ? "staff_updated_password" : standing === "Disabled" ? "staff_disabled" : "staff_updated", resourceType: "user", resourceId: req.params.id, details: { name, email, barangay, standing, role } });
  const [[staff]] = await pool.query("SELECT id, name, email, barangay, role, standing, verification FROM users WHERE id = ?", [Number(req.params.id)]);
  res.json({ staff });
});
app.get("/api/advisories", async (req, res) => {
  const status = req.query.status || "published";
  const viewer = req.auth;
  const scope = viewer?.role === "barangay_staff" ? " AND (a.barangay = ? OR a.audience = 'All barangays')" : "";
  const [advisories] = await pool.query(`SELECT a.*, u.name AS author,
    am.file_path AS media_url, am.media_type AS media_kind
    FROM advisories a LEFT JOIN users u ON u.id = a.created_by
    LEFT JOIN advisory_media am ON am.advisory_id = a.id
    WHERE a.status = ?${scope} ORDER BY a.created_at DESC`, scope ? [status, viewer.barangay] : [status]);
  res.json({ advisories: advisories.map((advisory) => ({
    ...advisory,
    media_url: publicMediaUrl(req, advisory.media_url),
  })) });
});
app.post("/api/uploads", (req, res, next) => {
  upload.single("file")(req, res, (error) => {
    if (error) {
      if (error.code === "LIMIT_FILE_SIZE") {
        return res.status(413).json({ error: "Video is too large. Please choose a file under 100MB." });
      }
      return res.status(400).json({ error: error.message || "Unsupported file type. Please upload a valid image or video." });
    }
    next();
  });
}, (req, res) => {
  if (!req.file) return res.status(400).json({ error: "Please select a photo or video" });
  const mediaKind = req.file.mimetype === "image/gif" ? "gif" : req.file.mimetype.startsWith("video/") ? "video" : "photo";
  res.status(201).json({ url: `${req.protocol}://${req.get("host")}/uploads/${req.file.filename}`, mediaKind, originalName: req.file.originalname });
});
app.post("/api/uploads/gif", upload.single("file"), (req, res) => {
  if (!req.file) return res.status(400).json({ error: "Please select a video" });
  const outputName = `${req.file.filename}.gif`;
  const outputPath = path.join(uploadDirectory, outputName);
  const converter = spawn(ffmpegPath, ["-y", "-i", req.file.path, "-t", "8", "-vf", "fps=12,scale=480:-1:flags=lanczos,split[s0][s1];[s0]palettegen=max_colors=128[p];[s1][p]paletteuse=dither=sierra2_4a", outputPath]);
  let errorOutput = "";
  converter.stderr.on("data", (chunk) => { errorOutput += chunk.toString(); });
  converter.on("close", (code) => {
    fs.rm(req.file.path, { force: true }, () => {});
    if (code !== 0) return res.status(422).json({ error: "Could not convert video to GIF", details: errorOutput.slice(-300) });
    res.status(201).json({ url: `${req.protocol}://${req.get("host")}/uploads/${outputName}`, mediaKind: "gif", originalName: req.file.originalname });
  });
});
app.post("/api/uploads/convert-gif", (req, res) => {
  const { url: bodyUrl } = req.body ?? {};
  const url = bodyUrl || req.query.url;
  if (!url) return res.status(400).json({ error: "A video URL is required" });
  const sourceName = path.basename(new URL(String(url)).pathname);
  const sourcePath = path.join(uploadDirectory, sourceName);
  if (!fs.existsSync(sourcePath)) return res.status(404).json({ error: "Uploaded video file was not found" });
  const outputName = `${path.parse(sourceName).name}-${Date.now()}.gif`;
  const outputPath = path.join(uploadDirectory, outputName);
  const converter = spawn(ffmpegPath, ["-y", "-i", sourcePath, "-t", "8", "-vf", "fps=12,scale=480:-1:flags=lanczos,split[s0][s1];[s0]palettegen=max_colors=128[p];[s1][p]paletteuse=dither=sierra2_4a", outputPath]);
  let errorOutput = "";
  converter.stderr.on("data", (chunk) => { errorOutput += chunk.toString(); });
  converter.on("close", (code) => {
    if (code !== 0) return res.status(422).json({ error: "Could not convert video to GIF", details: errorOutput.slice(-300) });
    res.status(201).json({ url: `${req.protocol}://${req.get("host")}/uploads/${outputName}`, mediaKind: "gif" });
  });
});
app.post("/api/advisories/:id/convert-gif", async (req, res) => {
  const advisoryId = Number(req.params.id);
  const [mediaRows] = await pool.query("SELECT id, file_path, media_type FROM advisory_media WHERE advisory_id = ? ORDER BY id DESC LIMIT 1", [advisoryId]);
  const media = mediaRows[0];
  if (!media || media.media_type !== "video") return res.status(400).json({ error: "This advisory has no attached video to convert" });
  const sourceName = path.basename(new URL(String(media.file_path)).pathname);
  const sourcePath = path.join(uploadDirectory, sourceName);
  if (!fs.existsSync(sourcePath)) return res.status(404).json({ error: "Attached video file was not found" });
  const outputName = `${path.parse(sourceName).name}-${Date.now()}.gif`;
  const outputPath = path.join(uploadDirectory, outputName);
  const converter = spawn(ffmpegPath, ["-y", "-i", sourcePath, "-t", "8", "-vf", "fps=12,scale=480:-1:flags=lanczos,split[s0][s1];[s0]palettegen=max_colors=128[p];[s1][p]paletteuse=dither=sierra2_4a", outputPath]);
  let errorOutput = "";
  converter.stderr.on("data", (chunk) => { errorOutput += chunk.toString(); });
  converter.on("close", async (code) => {
    if (code !== 0) return res.status(422).json({ error: "Could not convert the attached video to GIF", details: errorOutput.slice(-300) });
    const gifUrl = `${req.protocol}://${req.get("host")}/uploads/${outputName}`;
    await pool.query("UPDATE advisory_media SET file_path = ?, media_type = 'gif' WHERE id = ?", [gifUrl, media.id]);
    res.json({ url: gifUrl, mediaKind: "gif" });
  });
});
app.post("/api/advisories", async (req, res) => {
  const { type = "gen", title, message, audience = "All barangays", barangay, mediaUrl, mediaKind } = req.body ?? {};
  const publisher = req.auth;
  const adminId = publisher.id;
  const targetBarangay = publisher?.role === "barangay_staff" ? publisher.barangay : barangay ?? null;
  const targetAudience = publisher?.role === "barangay_staff" ? publisher.barangay : audience;
  if (!title?.trim() || !message?.trim()) return res.status(400).json({ error: "Title and message are required" });
  const [result] = await pool.query("INSERT INTO advisories (type, title, message, audience, barangay, created_by, published_at) VALUES (?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP)", [type, title.trim(), message.trim(), targetAudience, targetBarangay, adminId ?? null]);
  if (mediaUrl) await pool.query("INSERT INTO advisory_media (advisory_id, file_path, media_type) VALUES (?, ?, ?)", [result.insertId, mediaUrl, mediaKind || "photo"]);
  const [advisories] = await pool.query("SELECT * FROM advisories WHERE id = ?", [result.insertId]);
  await writeAuditLog(req, { actorId: adminId, action: "advisory_created", resourceType: "advisory", resourceId: result.insertId, details: { title: title.trim(), audience } });
  res.status(201).json({ advisory: advisories[0] });
});
app.patch("/api/advisories/:id", async (req, res) => {
  const { type, title, message, audience, barangay, mediaUrl, mediaKind } = req.body ?? {};
  const editor = req.auth;
  if (!title?.trim() || !message?.trim()) return res.status(400).json({ error: "Title and message are required" });
  const editScope = editor?.role === "barangay_staff" ? " AND barangay = ?" : "";
  const targetAudience = editor?.role === "barangay_staff" ? editor.barangay : audience;
  await pool.query(`UPDATE advisories SET type = COALESCE(?, type), title = ?, message = ?, audience = COALESCE(?, audience), barangay = COALESCE(?, barangay) WHERE id = ?${editScope}`, editScope ? [type ?? null, title.trim(), message.trim(), targetAudience ?? null, editor.barangay, Number(req.params.id), editor.barangay] : [type ?? null, title.trim(), message.trim(), targetAudience ?? null, barangay ?? null, Number(req.params.id)]);
  await pool.query("DELETE FROM advisory_media WHERE advisory_id = ?", [Number(req.params.id)]);
  if (mediaUrl) await pool.query("INSERT INTO advisory_media (advisory_id, file_path, media_type) VALUES (?, ?, ?)", [Number(req.params.id), mediaUrl, mediaKind || "photo"]);
  const [advisories] = await pool.query("SELECT * FROM advisories WHERE id = ?", [Number(req.params.id)]);
  if (!advisories[0]) return res.status(404).json({ error: "Advisory not found" });
  await writeAuditLog(req, { actorId: req.body?.adminId, action: "advisory_updated", resourceType: "advisory", resourceId: req.params.id, details: { title: title.trim() } });
  res.json({ advisory: advisories[0] });
});
app.delete("/api/advisories/:id", async (req, res) => {
  const adminId = req.auth.id;
  const [result] = await pool.query("UPDATE advisories SET status = 'archived' WHERE id = ?", [Number(req.params.id)]);
  if (!result.affectedRows) return res.status(404).json({ error: "Advisory not found" });
  await writeAuditLog(req, { actorId: adminId, action: "advisory_archived", resourceType: "advisory", resourceId: req.params.id });
  res.status(204).end();
});
app.patch("/api/users/:id/moderation", async (req, res) => {
  const { action, reason, duration, note } = req.body ?? {};
  const adminId = req.auth.id;
  const allowedActions = ["warn", "suspend", "ban", "restore"];
  if (!allowedActions.includes(action) || !reason) return res.status(400).json({ error: "A valid action and reason are required" });
  const [users] = await pool.query("SELECT id FROM users WHERE id = ? AND role = 'resident'", [Number(req.params.id)]);
  if (!users[0]) return res.status(404).json({ error: "Resident account not found" });
  const moderator = req.auth;
  const [[targetUser]] = await pool.query("SELECT barangay FROM users WHERE id = ?", [Number(req.params.id)]);
  if (moderator?.role === "barangay_staff" && moderator.barangay !== targetUser?.barangay) return res.status(403).json({ error: "You can only manage members in your barangay" });
  const standing = action === "warn" ? "Warned" : action === "suspend" ? "Suspended" : action === "ban" ? "Banned" : "Active";
  await pool.query("INSERT INTO moderation_actions (user_id, admin_id, action, reason, duration, note) VALUES (?, ?, ?, ?, ?, ?)", [users[0].id, adminId ?? null, action, reason, duration ?? null, note ?? null]);
  await pool.query("UPDATE users SET standing = ? WHERE id = ?", [standing, users[0].id]);
  await pool.query("INSERT INTO notifications (user_id, type, title, message) VALUES (?, 'account', ?, ?)", [users[0].id, `Account ${standing.toLowerCase()}`, `Your InfraTrack account has been ${standing.toLowerCase()}.`]);
  const [updated] = await pool.query("SELECT id, name, email, barangay, standing, verification FROM users WHERE id = ?", [users[0].id]);
  await writeAuditLog(req, { actorId: adminId, action: `user_${action}`, resourceType: "user", resourceId: req.params.id, details: { reason, duration, note } });
  res.json({ user: updated[0] });
});
app.get("/api/reports", async (req, res) => {
  const userId = Number(req.query.userId);
  const [reports] = await pool.query(`SELECT r.*, u.name AS reporter FROM reports r LEFT JOIN users u ON u.id = r.reporter_id ${userId ? "WHERE r.reporter_id = ?" : ""} ORDER BY r.created_at DESC`, userId ? [userId] : []);
  res.json({ reports });
});
app.post("/api/reports", async (req, res) => {
  const { title, description, category, location, latitude, longitude, severity = "Medium", reporterId } = req.body ?? {};
  if (!title || !description || !category) return res.status(400).json({ error: "Title, description, and category are required" });

  const parsedLat = latitude == null || latitude === "" ? null : Number(latitude);
  const parsedLng = longitude == null || longitude === "" ? null : Number(longitude);
  if (Number.isFinite(parsedLat) && Number.isFinite(parsedLng)) {
    const boundaryResult = validateBarangayCoordinates({ latitude: parsedLat, longitude: parsedLng, location });
    if (!boundaryResult.valid) {
      return res.status(422).json({ error: boundaryResult.reason });
    }
  }

  const resolvedLocation = location || (Number.isFinite(parsedLat) && Number.isFinite(parsedLng) ? validateBarangayCoordinates({ latitude: parsedLat, longitude: parsedLng, location }).matchedBarangay || "Mati City" : "Mati City");
  const id = publicId();
  const [result] = await pool.query("INSERT INTO reports (public_id, title, description, category, location, latitude, longitude, severity, reporter_id, due_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, DATE_ADD(CURRENT_TIMESTAMP, INTERVAL 3 DAY))", [id, title, description, category, resolvedLocation, parsedLat ?? null, parsedLng ?? null, severity, reporterId ?? null]);
  await pool.query("INSERT INTO report_events (report_id, status, note) VALUES (?, 'Reported', ?)", [result.insertId, "Report submitted by resident"]);
  const [reports] = await pool.query("SELECT * FROM reports WHERE id = ?", [result.insertId]);
  const report = reports[0];
  await evaluateIssueAutomation(report);
  await writeAuditLog(req, { actorId: req.auth?.id ?? reporterId, action: "report_created", resourceType: "report", resourceId: id, details: { title, category, location: resolvedLocation } });
  res.status(201).json({ report });
});
app.patch("/api/issues/:id", async (req, res) => {
  const { status, assignedTeam, resolutionNote, severity } = req.body ?? {};
  const [rows] = await pool.query("SELECT * FROM reports WHERE public_id = ? OR id = ?", [req.params.id, Number(req.params.id)]);
  const report = rows[0];
  if (!report) return res.status(404).json({ error: "Report not found" });
  const editor = req.auth;
  if (editor?.role === "barangay_staff" && editor.barangay !== report.location) return res.status(403).json({ error: "You can only manage issues in your barangay" });
  await pool.query("UPDATE reports SET status = COALESCE(?, status), assigned_team = COALESCE(?, assigned_team), resolution_note = COALESCE(?, resolution_note), severity = COALESCE(?, severity) WHERE id = ?", [status ?? null, assignedTeam ?? null, resolutionNote ?? null, severity ?? null, report.id]);
  if (status && status !== report.status) await pool.query("INSERT INTO report_events (report_id, status, note) VALUES (?, ?, ?)", [report.id, status, resolutionNote ?? null]);
  const [updated] = await pool.query("SELECT * FROM reports WHERE id = ?", [report.id]);
  const action = status === "Verified by inspector" ? "issue_accepted" : status === "Rejected" ? "issue_rejected" : status === "Resolved" ? "issue_resolved" : status === "Archived" ? "issue_archived" : assignedTeam && assignedTeam !== report.assigned_team ? "issue_assigned" : "issue_updated";
  await evaluateIssueAutomation(updated[0]);
  await writeAuditLog(req, { actorId: editor.id, action, resourceType: "report", resourceId: report.public_id, details: { before: { status: report.status, assignedTeam: report.assigned_team || "Unassigned", severity: report.severity }, after: { status: status ?? report.status, assignedTeam: assignedTeam ?? (report.assigned_team || "Unassigned"), severity: severity ?? report.severity, resolutionNote: resolutionNote ?? report.resolution_note } } });
  res.json({ report: updated[0] });
});
app.use(express.static(path.join(__dirname, "dist"), { maxAge: "1h", etag: true }));
app.use((_req, res) => res.sendFile(path.join(__dirname, "dist", "index.html")));

initializeDatabase()
  .then(ensureDefaultStaffAccount)
  .then(ensureDefaultTeams)
  .then(seedAdvisories)
  .then(() => {
    setInterval(() => {
      sweepEscalations().catch((error) => console.error("Escalation sweep failed:", error.message));
    }, 5 * 60 * 1000);
    return app.listen(port, () => { scheduleDatabaseBackups(); console.log(`InfraTrack Admin server running on http://localhost:${port} using MySQL database ${dbName}`); });
  })
  .catch((error) => { console.error("Unable to initialize XAMPP MySQL database:", error.message); process.exit(1); });
