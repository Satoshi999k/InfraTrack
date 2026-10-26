import "dotenv/config";
import express from "express";
import path from "node:path";
import { fileURLToPath } from "node:url";
import crypto from "node:crypto";
import net from "node:net";
import mysql from "mysql2/promise";
import multer from "multer";
import fs from "node:fs";
import { tmpdir } from "node:os";
import { spawn } from "node:child_process";
import { cert, getApps, initializeApp } from "firebase-admin/app";
import { getMessaging } from "firebase-admin/messaging";
import { createPortableDatabaseBackup } from "./databaseBackup.js";
import {
  describeMysqlDumpNotFound,
  resolveMysqlDumpPath,
} from "./databaseBackup.js";
import { serializeAdminAuthUser } from "./authUser.js";
import { assessReportSeverity, REPORT_SEVERITIES } from "./severityAssessment.js";
import ffmpegPath from "ffmpeg-static";
import { computeDuplicateMatch, escalateIssueSeverity } from "./automation.js";
import {
  normalizeSystemSettings,
  validateSystemSettingsUpdate,
} from "./systemSettings.js";
import { validateBarangayCoordinates } from "./barangay-boundaries.js";
import {
  getAdvisoryReadScope,
  getAdvisoryScope,
  getResidentScope,
  getReportScope,
} from "./advisoryAccess.js";
import { canManageSystemSettings } from "./permissions.js";
import { sendEmailNotification } from "./emailNotifications.js";
import { analyzeReportThemes } from "./thematicAnalysis.js";
import {
  ChatProviderError,
  generateChatReply,
  normalizeChatRequestMessages,
} from "./chatbotProviders.js";
import {
  moderationNotification,
  standingAfterModeration,
  suspensionHours,
} from "./moderationPolicy.js";
import {
  attachReportEventsToReports,
  progressUpdateError,
} from "./progressWorkflow.js";
import { verificationApprovalNotification } from "./verificationNotifications.js";
import {
  canReplyToReport,
  isReportDiscussionOpen,
  validateReportComment,
} from "./reportDiscussion.js";
import {
  canOwnReportRating,
  canRateReport,
  validateReportRating,
} from "./reportRating.js";
import {
  aggregateReportCategories,
  normalizeReportCategory,
  REPORT_CATEGORIES,
} from "./reportCategories.js";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const app = express();
app.set("trust proxy", process.env.TRUST_PROXY === "true");
const port = Number(process.env.PORT || 3001);
const forceHttps = String(process.env.FORCE_HTTPS || "false").toLowerCase() === "true";
const recaptchaSecret = process.env.RECAPTCHA_SECRET_KEY || "";
const loginAttempts = new Map();
const chatbotRequests = new Map();
let firebaseMessaging = null;
let firebaseConfigurationWarningLogged = false;
let firebaseConfigurationErrorLogged = false;
const loginMaxAttempts = Number(process.env.LOGIN_MAX_ATTEMPTS || 10);
if (!Number.isInteger(loginMaxAttempts) || loginMaxAttempts < 1) {
  throw new Error("LOGIN_MAX_ATTEMPTS must be a positive integer");
}
const dbName = process.env.DB_NAME || "infratrack";
const dbSsl = /^true$/i.test(process.env.DB_SSL || "false");
const dbConfig = {
  host: process.env.DB_HOST || "127.0.0.1",
  port: Number(process.env.DB_PORT || 3306),
  user: process.env.DB_USER || "root",
  password: process.env.DB_PASSWORD || "",
  ssl: dbSsl ? { minVersion: "TLSv1.2" } : undefined,
};
const pool = mysql.createPool({ ...dbConfig, database: dbName, waitForConnections: true, connectionLimit: 10 });
const uploadDirectory = path.join(__dirname, "uploads");
const backupDirectory = path.join(__dirname, "backups");
fs.mkdirSync(uploadDirectory, { recursive: true });
fs.mkdirSync(backupDirectory, { recursive: true });
const uploadStorage = multer.diskStorage({
  destination: (_req, _file, callback) => callback(null, uploadDirectory),
  filename: (_req, file, callback) => {
    const extensionByMimeType = {
      "image/gif": ".gif",
      "image/jpeg": ".jpg",
      "image/png": ".png",
      "image/webp": ".webp",
      "video/mp4": ".mp4",
      "video/webm": ".webm",
      "video/quicktime": ".mov",
    };
    const extension =
      extensionByMimeType[file.mimetype] ||
      path.extname(file.originalname).toLowerCase() ||
      "";
    callback(null, `${crypto.randomBytes(16).toString("hex")}${extension}`);
  },
});
const upload = multer({
  storage: uploadStorage,
  limits: { fileSize: 100 * 1024 * 1024 },
  fileFilter: (_req, file, callback) => {
    const isImage = /^image\//.test(file.mimetype);
    const isVideo = /^video\//.test(file.mimetype);
    const isGif = file.mimetype === "image/gif";
    if (isImage || isVideo || isGif) return callback(null, true);
    callback(new Error("Unsupported file type. Please upload an image or video."));
  },
});
const profilePhotoUpload = multer({
  storage: uploadStorage,
  limits: { fileSize: 8 * 1024 * 1024 },
  fileFilter: (_req, file, callback) => {
    if (["image/jpeg", "image/png", "image/webp"].includes(file.mimetype)) {
      return callback(null, true);
    }
    callback(new Error("Choose a JPG, PNG, or WebP profile photo."));
  },
});
const severityAssessmentUpload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 20 * 1024 * 1024 },
  fileFilter: (_req, file, callback) => {
    if (
      file.mimetype === "image/jpeg" ||
      file.mimetype === "video/mp4" ||
      file.mimetype === "video/quicktime"
    ) {
      return callback(null, true);
    }
    callback(new Error("Use a JPG photo or MP4/MOV video for severity analysis."));
  },
});
const cloudinaryCloudName = String(process.env.CLOUDINARY_CLOUD_NAME || "").trim();
const cloudinaryUploadPreset = String(process.env.CLOUDINARY_UPLOAD_PRESET || "").trim();
const cloudinaryApiKey = String(process.env.CLOUDINARY_API_KEY || "").trim();
const cloudinaryApiSecret = String(process.env.CLOUDINARY_API_SECRET || "").trim();
const hasCloudinaryStorage = Boolean(cloudinaryCloudName && cloudinaryUploadPreset);
const hasSignedCloudinaryStorage = Boolean(cloudinaryCloudName && cloudinaryApiKey && cloudinaryApiSecret);
const cloudinaryMediaHost = cloudinaryCloudName
  ? `res.cloudinary.com`
  : "";

async function uploadToCloudinary(file, folder = "infratrack/advisories") {
  const form = new FormData();
  form.append("file", new Blob([await fs.promises.readFile(file.path)], { type: file.mimetype }), file.originalname);
  form.append("resource_type", "auto");
  const uploadParameters = {
    folder,
    timestamp: Math.floor(Date.now() / 1000).toString(),
  };

  if (hasSignedCloudinaryStorage) {
    const signatureBase = Object.entries(uploadParameters)
      .sort(([left], [right]) => left.localeCompare(right))
      .map(([key, value]) => `${key}=${value}`)
      .join("&");
    const signature = crypto
      .createHash("sha1")
      .update(`${signatureBase}${cloudinaryApiSecret}`)
      .digest("hex");
    form.append("api_key", cloudinaryApiKey);
    form.append("signature", signature);
    for (const [key, value] of Object.entries(uploadParameters)) form.append(key, value);
  } else if (hasCloudinaryStorage) {
    form.append("upload_preset", cloudinaryUploadPreset);
    form.append("folder", uploadParameters.folder);
  } else {
    return null;
  }

  const response = await fetch(
    `https://api.cloudinary.com/v1_1/${encodeURIComponent(cloudinaryCloudName)}/auto/upload`,
    { method: "POST", body: form },
  );
  const result = await response.json();
  if (!response.ok || !result.secure_url) {
    throw new Error(result.error?.message || "The media storage service rejected the upload.");
  }
  return result.secure_url;
}

async function removeTemporaryUpload(file) {
  if (file?.path) {
    await fs.promises.rm(file.path, { force: true }).catch((error) => {
      console.error("Unable to remove temporary upload:", error.message);
    });
  }
}

async function downloadMediaForConversion(mediaUrl) {
  const parsedUrl = new URL(String(mediaUrl));
  if (!parsedUrl.hostname.endsWith(".cloudinary.com")) {
    return path.join(uploadDirectory, path.basename(parsedUrl.pathname));
  }
  const response = await fetch(parsedUrl);
  if (!response.ok) throw new Error(`Unable to download the uploaded video (${response.status}).`);
  const temporaryPath = path.join(uploadDirectory, `conversion-${crypto.randomBytes(12).toString("hex")}.video`);
  await fs.promises.writeFile(temporaryPath, Buffer.from(await response.arrayBuffer()));
  return temporaryPath;
}

function convertVideoFileToGif(sourcePath, outputPath) {
  return new Promise((resolve, reject) => {
    const converter = spawn(ffmpegPath, ["-y", "-i", sourcePath, "-t", "8", "-vf", "fps=12,scale=480:-1:flags=lanczos,split[s0][s1];[s0]palettegen=max_colors=128[p];[s1][p]paletteuse=dither=sierra2_4a", outputPath]);
    let errorOutput = "";
    converter.stderr.on("data", (chunk) => { errorOutput += chunk.toString(); });
    converter.on("error", reject);
    converter.on("close", (code) => code === 0 ? resolve() : reject(new Error(`Could not convert video to GIF: ${errorOutput.slice(-300)}`)));
  });
}

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
    if (!["http:", "https:"].includes(parsed.protocol) || parsed.host !== req.get("host")) {
      return parsed.toString();
    }
    return `${req.protocol}://${req.get("host")}${parsed.pathname}`;
  } catch {
    return filePath;
  }
};
const isDurableMediaUrl = (value) => {
  try {
    const parsed = new URL(String(value));
    return parsed.protocol === "https:" && (
      parsed.hostname === cloudinaryMediaHost ||
      parsed.hostname.endsWith(".cloudinary.com")
    );
  } catch {
    return false;
  }
};
const csvValue = (value) => `"${String(value ?? "").replaceAll('"', '""')}"`;
function createCliDatabaseBackup() {
  return new Promise((resolve, reject) => {
    const dumpPath = resolveMysqlDumpPath(__dirname);
    const filePath = path.join(backupDirectory, `infratrack-${new Date().toISOString().replaceAll(/[:.]/g, "-")}.sql`);
    const args = [`--host=${dbConfig.host}`, `--port=${dbConfig.port}`, `--user=${dbConfig.user}`, `--password=${dbConfig.password}`, "--single-transaction", "--routines", dbName];
    const output = fs.createWriteStream(filePath);
    const dump = spawn(dumpPath, args, { windowsHide: true });
    let errorOutput = "";
    dump.stderr.on("data", (chunk) => { errorOutput += chunk.toString(); });
    dump.on("error", (error) => {
      output.destroy();
      fs.rm(filePath, { force: true }, () => {});
      reject(
        error.code === "ENOENT"
          ? new Error(describeMysqlDumpNotFound(dumpPath))
          : error,
      );
    });
    dump.on("close", (code) => {
      output.close();
      if (code !== 0) { fs.rm(filePath, { force: true }, () => {}); return reject(new Error(errorOutput || `mysqldump exited with code ${code}`)); }
      resolve(filePath);
    });
    dump.stdout.pipe(output);
  });
}
async function createDatabaseBackup() {
  const timestamp = new Date().toISOString().replaceAll(/[:.]/g, "-");
  const fileName = `infratrack-${timestamp}.sql`;
  const contents = await createPortableDatabaseBackup(pool, dbName);
  let filePath = path.join(backupDirectory, fileName);
  try {
    await fs.promises.writeFile(filePath, contents, { flag: "wx" });
  } catch (error) {
    if (!["EACCES", "EROFS", "ENOENT"].includes(error.code)) throw error;
    filePath = path.join(tmpdir(), fileName);
    await fs.promises.writeFile(filePath, contents, { flag: "wx" });
  }
  return filePath;
}

function scheduleDatabaseBackups() {
  const hours = Number(process.env.BACKUP_INTERVAL_HOURS || 24);
  if (hours > 0) setInterval(() => createDatabaseBackup().catch((error) => console.error("Scheduled backup failed:", error.message)), hours * 60 * 60 * 1000);
}
const normalizeClientIp = (value) => {
  const candidate = String(value || "").trim().replace(/^\[|\]$/g, "").replace(/^::ffff:/i, "");
  return net.isIP(candidate) ? candidate : "unknown";
};
const clientIp = (req) => normalizeClientIp(process.env.TRUST_PROXY === "true" ? req.ip : req.socket.remoteAddress);
const isAutomatedUserAgent = (req) => /bot|crawler|spider|scrapy|curl|wget|python-requests|headless/i.test(String(req.get("user-agent") || ""));
const isPublicIp = (value) => {
  const ip = String(value || "").trim();
  if (!ip || ip === "::1" || ip === "127.0.0.1" || ip.toLowerCase() === "localhost") return false;
  if (/^(10\.|127\.|192\.168\.|169\.254\.)/.test(ip)) return false;
  if (/^172\.(1[6-9]|2\d|3[0-1])\./.test(ip)) return false;
  if (/^(fc|fd|fe8|fe9|fea|feb)/i.test(ip)) return false;
  return true;
};
async function verifyRecaptcha(token, ip) {
  if (!recaptchaSecret) return { ok: true, configured: false };
  if (!token) {
    console.warn("reCAPTCHA verification rejected", { errorCodes: ["missing-input-response"] });
    return { ok: false, configured: true };
  }
  const response = await fetch("https://www.google.com/recaptcha/api/siteverify", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({ secret: recaptchaSecret, response: token, remoteip: ip }),
  });
  const result = await response.json();
  const ok = Boolean(result.success) && Number(result.score ?? 1) >= 0.5;
  if (!ok) {
    console.warn("reCAPTCHA verification rejected", {
      errorCodes: result["error-codes"] ?? [],
      score: result.score ?? null,
      hostname: result.hostname ?? null,
      action: result.action ?? null,
    });
  }
  return { ok, configured: true };
}

async function readSystemSettings() {
  const [rows] = await pool.query("SELECT setting_key, setting_value FROM system_settings");
  const storedSettings = Object.fromEntries(rows.map(({ setting_key, setting_value }) => {
    try { return [setting_key, JSON.parse(setting_value)]; } catch { return [setting_key, setting_value]; }
  }));
  return normalizeSystemSettings(storedSettings);
}

function getFirebaseMessagingClient() {
  const serviceAccountJson = process.env.FIREBASE_SERVICE_ACCOUNT_JSON;
  if (!serviceAccountJson) {
    if (!firebaseConfigurationWarningLogged) {
      console.warn("FCM delivery is disabled: FIREBASE_SERVICE_ACCOUNT_JSON is not configured.");
      firebaseConfigurationWarningLogged = true;
    }
    return null;
  }
  if (firebaseMessaging) return firebaseMessaging;

  try {
    const serviceAccount = JSON.parse(serviceAccountJson);
    if (
      !serviceAccount.project_id ||
      !serviceAccount.client_email ||
      !serviceAccount.private_key
    ) {
      throw new Error("Firebase service-account JSON is missing required fields.");
    }
    const app =
      getApps().find((candidate) => candidate.name === "infratrack-push") ??
      initializeApp(
        { credential: cert(serviceAccount) },
        "infratrack-push",
      );
    firebaseMessaging = getMessaging(app);
    return firebaseMessaging;
  } catch (error) {
    if (!firebaseConfigurationErrorLogged) {
      console.error("FCM delivery could not initialize:", error.message);
      firebaseConfigurationErrorLogged = true;
    }
    return null;
  }
}

async function sendNotificationPush(notification) {
  const messaging = getFirebaseMessagingClient();
  if (!messaging) return;
  const [devices] = await pool.query(
    `SELECT tokens.token
     FROM push_device_tokens tokens
     LEFT JOIN user_preferences preferences ON preferences.user_id = tokens.user_id
     WHERE tokens.user_id = ?
       AND COALESCE(preferences.allow_notifications, 1) = 1`,
    [notification.user_id],
  );
  const tokens = devices.map(({ token }) => token);
  const data = Object.fromEntries(
    Object.entries({
      notificationId: notification.id,
      reportId: notification.report_id,
      advisoryId: notification.advisory_id,
      type: notification.type,
      title: notification.title,
      message: String(notification.message).slice(0, 1000),
      imageUrl: notification.image_url,
      mediaKind: notification.media_kind,
      mediaUrl: notification.media_url,
    })
      .filter(([, value]) => value !== null && value !== undefined)
      .map(([key, value]) => [key, String(value)]),
  );

  for (let offset = 0; offset < tokens.length; offset += 500) {
    const batch = tokens.slice(offset, offset + 500);
    const result = await messaging.sendEachForMulticast({
      tokens: batch,
      notification: {
        title: notification.title,
        body: String(notification.message).slice(0, 1000),
      },
      data,
      android: {
        priority: "high",
        notification: {
          channelId: "infratrack_city_updates_v3",
          sound: "default",
          ...(notification.image_url
            ? { imageUrl: notification.image_url }
            : {}),
        },
      },
    });
    for (let index = 0; index < result.responses.length; index += 1) {
      const response = result.responses[index];
      const errorCode = response.error?.code;
      if (
        !response.success &&
        (errorCode === "messaging/registration-token-not-registered" ||
          errorCode === "messaging/invalid-registration-token")
      ) {
        await pool.query(
          "DELETE FROM push_device_tokens WHERE token = ?",
          [batch[index]],
        );
      }
    }
  }
}

async function deliverNotificationPush(notification) {
  try {
    await sendNotificationPush(notification);
  } catch (error) {
    console.error(
      `FCM delivery failed for notification ${notification.id}:`,
      error.message,
    );
  }
}

async function queueNotification({ userId, reportId = null, advisoryId = null, type, title, message, channel = "push" }) {
  if (!userId || !title || !message) return null;
  const [[preferences]] = await pool.query(
    "SELECT allow_notifications FROM user_preferences WHERE user_id = ?",
    [Number(userId)],
  );
  if (preferences && Number(preferences.allow_notifications) === 0) return null;
  const [result] = await pool.query(
    "INSERT INTO notifications (user_id, report_id, advisory_id, type, title, message, channel) VALUES (?, ?, ?, ?, ?, ?, ?)",
    [Number(userId), reportId ?? null, advisoryId ?? null, type || "system", title, message, channel],
  );
  await deliverNotificationPush({
    id: result.insertId,
    user_id: Number(userId),
    report_id: reportId ?? null,
    advisory_id: advisoryId ?? null,
    type: type || "system",
    title,
    message,
  });
  return { ok: true };
}

async function queueAdvisoryNotifications({
  advisoryId,
  advisoryType,
  title,
  message,
  audience,
  imageUrl = null,
  mediaKind = null,
  mediaUrl = null,
}) {
  const allBarangays = audience === "All barangays";
  const targetBarangay = allBarangays
    ? ""
    : String(audience ?? "")
        .trim()
        .replace(/^(?:barangay|brgy\.?)\s*/i, "");
  const notificationType =
    advisoryType === "alert" || advisoryType === "advertisement"
      ? "advertisement"
      : advisoryType === "maint" || advisoryType === "maintenance"
        ? "maintenance"
        : "announcement";

  await pool.query(
    `INSERT INTO notifications
      (user_id, advisory_id, type, title, message, channel)
     SELECT u.id, ?, ?, ?, ?, 'push'
     FROM users u
     LEFT JOIN user_preferences preferences ON preferences.user_id = u.id
     WHERE u.role = 'resident'
       AND COALESCE(preferences.allow_notifications, 1) = 1
       AND (
         ? = 1
         OR LOWER(TRIM(u.barangay)) = LOWER(?)
         OR LOWER(TRIM(
           REPLACE(
             REPLACE(LOWER(u.barangay), 'barangay ', ''),
             'brgy. ',
             ''
           )
         )) = LOWER(?)
       )`,
    [
      advisoryId,
      notificationType,
      title,
      message,
      allBarangays ? 1 : 0,
      String(audience ?? ""),
      targetBarangay,
    ],
  );
  const [queuedNotifications] = await pool.query(
    "SELECT id, user_id, advisory_id, type, title, message FROM notifications WHERE advisory_id = ? AND type = ? AND title = ?",
    [advisoryId, notificationType, title],
  );
  for (const notification of queuedNotifications) {
    await deliverNotificationPush({
      ...notification,
      image_url: imageUrl,
      media_kind: mediaKind,
      media_url: mediaUrl,
    });
  }
}

async function dispatchNotification({ channel = "email", recipient, subject, body }) {
  const resolvedChannel = channel || "email";
  if (resolvedChannel === "email" && process.env.BREVO_API_KEY) {
    try {
      return await sendEmailNotification({ recipient, subject, body });
    } catch (error) {
      console.warn("Brevo notification failed:", error.message);
      return { sent: false, configured: true };
    }
  }
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

async function notifyPasswordChanged(user, changedByAdmin = false) {
  const subject = "Your InfraTrack password was changed";
  const action = changedByAdmin ? "An administrator reset your password" : "Your password was changed";
  const body = `Hello ${user.name || "there"},\n\n${action} for your InfraTrack account. If you did not expect this change, contact your Mati City administrator.\n\nFor your security, this email does not contain your password.`;

  try {
    return await sendEmailNotification({
      recipient: user.email,
      subject,
      body,
      template: {
        eyebrow: "SECURITY ALERT",
        note: "For your security, this email does not include your password. If you did not request this change, contact your Mati City administrator.",
        actionUrl: process.env.APP_PUBLIC_URL,
        actionLabel: "Sign in to InfraTrack",
      },
    });
  } catch (error) {
    console.error(`Password-change email failed for account ${user.id}:`, error.message);
    return { sent: false, configured: true };
  }
}

async function notifyStaffAccountReady(staff) {
  const subject = "Your InfraTrack administrator account is ready";
  const body = `Hello ${staff.name || "there"},\n\nYour InfraTrack account is active with ${staff.role === "lgu" ? "LGU administrator" : "barangay staff"} access. Sign in using ${staff.email} and the initial password provided to you by your administrator.`;

  try {
    return await sendEmailNotification({
      recipient: staff.email,
      subject,
      body,
      template: {
        eyebrow: "ADMINISTRATOR ACCOUNT",
        note: "For your security, this email does not include your password. Your administrator should provide your initial sign-in credentials directly.",
        actionUrl: process.env.APP_PUBLIC_URL,
        actionLabel: "Sign in to InfraTrack",
      },
    });
  } catch (error) {
    console.error(`Staff account email failed for account ${staff.id}:`, error.message);
    return { sent: false, configured: true };
  }
}

async function notifyIssueStakeholders(report, eventType = "report") {
  const settings = await readSystemSettings();
  const settingKey = {
    newReport: "newReportAlerts",
    duplicate: "duplicateAlerts",
    escalation: "reportAlerts",
  }[eventType];
  if (!settingKey) throw new Error(`Unsupported issue notification event: ${eventType}`);
  if (settings[settingKey] === false) return;
  const [admins] = await pool.query("SELECT id, email, mobile, name FROM users WHERE role IN ('lgu', 'admin') ORDER BY id");
  const subject = eventType === "duplicate"
    ? `Duplicate issue detected: ${report.public_id || report.id}`
    : eventType === "newReport"
      ? `New issue report: ${report.public_id || report.id}`
      : `Priority escalation: ${report.public_id || report.id}`;
  const body = eventType === "duplicate"
    ? `A duplicate report may be related to ${report.public_id || report.id}. Review the issue queue for possible consolidation.`
    : eventType === "newReport"
      ? `A new ${report.severity || "Medium"} priority report was submitted: ${report.title || report.public_id || report.id}. Review it in the issue queue.`
      : `Issue ${report.public_id || report.id} has escalated to ${report.severity || "Critical"} and requires immediate follow-up.`;

  for (const admin of admins) {
    await queueNotification({
      userId: admin.id,
      reportId: report.id,
      type: eventType === "duplicate"
        ? "duplicate_issue"
        : eventType === "newReport"
          ? "new_report"
          : "priority_escalation",
      title: subject,
      message: body,
      channel: "push",
    });

    if (admin.email) await dispatchNotification({ channel: "email", recipient: admin.email, subject, body });
    if (admin.mobile) await dispatchNotification({ channel: "sms", recipient: admin.mobile, subject: subject.slice(0, 100), body });
  }
}

async function evaluateIssueAutomation(report) {
  const settings = await readSystemSettings();
  const escalationHours = {
    low: settings.lowSeverityEscalationHours,
    medium: settings.mediumSeverityEscalationHours,
    high: settings.highSeverityEscalationHours,
  };
  const reportId = Number(report.id);
  const [existing] = report.reporter_id == null
    ? [[]]
    : await pool.query(
        "SELECT id, public_id, title, category, location, latitude, longitude, created_at, severity, status, reporter_id FROM reports WHERE id <> ? AND reporter_id = ? AND status NOT IN ('Resolved', 'Rejected', 'Archived') ORDER BY created_at DESC LIMIT 200",
        [reportId, report.reporter_id],
      );
  const duplicate = existing.find((candidate) => computeDuplicateMatch(report, candidate));

  if (duplicate) {
    const details = `Matched existing report ${duplicate.public_id || duplicate.id} in the same barangay category.`;
    await pool.query("UPDATE reports SET duplicate_of = ?, duplicate_reason = ? WHERE id = ?", [duplicate.id, details, reportId]);
    await notifyIssueStakeholders({ ...report, public_id: report.public_id || report.id }, "duplicate");
    return { duplicateOf: duplicate.id, escalated: false };
  }
  if (report.duplicate_of) {
    await pool.query(
      "UPDATE reports SET duplicate_of = NULL, duplicate_reason = NULL WHERE id = ?",
      [reportId],
    );
  }

  const ageHours = report.created_at ? (Date.now() - new Date(report.created_at).getTime()) / 3600000 : 0;
  const nextSeverity = escalateIssueSeverity(report.severity, ageHours, escalationHours);
  if (nextSeverity !== report.severity && report.status && !["Resolved", "Rejected", "Archived"].includes(report.status)) {
    await pool.query(
      "UPDATE reports SET severity = ?, escalated_at = COALESCE(escalated_at, CURRENT_TIMESTAMP), due_at = CASE WHEN due_at IS NULL OR due_at > DATE_ADD(CURRENT_TIMESTAMP, INTERVAL 1 DAY) THEN DATE_ADD(CURRENT_TIMESTAMP, INTERVAL 1 DAY) ELSE due_at END WHERE id = ?",
      [nextSeverity, reportId],
    );
    await notifyIssueStakeholders({ ...report, severity: nextSeverity }, "escalation");
    return { duplicateOf: null, escalated: true, severity: nextSeverity };
  }

  return { duplicateOf: null, escalated: false };
}

async function sweepEscalations() {
  const settings = await readSystemSettings();
  const escalationHours = {
    low: settings.lowSeverityEscalationHours,
    medium: settings.mediumSeverityEscalationHours,
    high: settings.highSeverityEscalationHours,
  };
  const [rows] = await pool.query("SELECT r.* FROM reports r WHERE r.status NOT IN ('Resolved', 'Rejected', 'Archived') ORDER BY r.created_at DESC");
  for (const report of rows) {
    const ageHours = report.created_at ? (Date.now() - new Date(report.created_at).getTime()) / 3600000 : 0;
    const nextSeverity = escalateIssueSeverity(report.severity, ageHours, escalationHours);
    if (nextSeverity !== report.severity) {
      await pool.query(
        "UPDATE reports SET severity = ?, escalated_at = COALESCE(escalated_at, CURRENT_TIMESTAMP), due_at = CASE WHEN due_at IS NULL OR due_at > DATE_ADD(CURRENT_TIMESTAMP, INTERVAL 1 DAY) THEN DATE_ADD(CURRENT_TIMESTAMP, INTERVAL 1 DAY) ELSE due_at END WHERE id = ?",
        [nextSeverity, report.id],
      );
      await notifyIssueStakeholders({ ...report, severity: nextSeverity }, "escalation");
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
    avatar_url VARCHAR(500) NULL,
    password_hash VARCHAR(255) NOT NULL, role ENUM('resident','admin','lgu','barangay_staff') NOT NULL DEFAULT 'resident',
    standing VARCHAR(30) NOT NULL DEFAULT 'Active', verification VARCHAR(40) NOT NULL DEFAULT 'Pending ID match',
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
  ) ENGINE=InnoDB`);
  await pool.query("ALTER TABLE users ADD COLUMN IF NOT EXISTS suspended_until DATETIME NULL");
  await pool.query("ALTER TABLE users ADD COLUMN IF NOT EXISTS avatar_url VARCHAR(500) NULL");
  await pool.query("UPDATE users SET standing = 'Active' WHERE standing = 'Warned'");
  await pool.query("ALTER TABLE users MODIFY COLUMN password_hash VARCHAR(255) NOT NULL");
  await pool.query(`CREATE TABLE IF NOT EXISTS reports (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY, public_id VARCHAR(32) NOT NULL UNIQUE,
    title VARCHAR(255) NOT NULL, description TEXT NOT NULL, category VARCHAR(80) NOT NULL,
    location VARCHAR(255) NOT NULL DEFAULT 'Mati City', latitude DECIMAL(10,7), longitude DECIMAL(10,7),
    severity VARCHAR(30) NOT NULL DEFAULT 'Medium', status VARCHAR(40) NOT NULL DEFAULT 'Reported',
    duplicate_of INT UNSIGNED NULL, duplicate_reason VARCHAR(255) NULL, escalated_at TIMESTAMP NULL,
    reporter_id INT UNSIGNED NULL, assigned_team VARCHAR(160), resolution_note TEXT,
    progress_percentage TINYINT UNSIGNED NOT NULL DEFAULT 0,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP, updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT reports_reporter_fk FOREIGN KEY (reporter_id) REFERENCES users(id) ON DELETE SET NULL
  ) ENGINE=InnoDB`);
  await pool.query("ALTER TABLE reports ADD COLUMN IF NOT EXISTS due_at TIMESTAMP NULL");
  await pool.query("ALTER TABLE reports ADD COLUMN IF NOT EXISTS duplicate_of INT UNSIGNED NULL");
  await pool.query("ALTER TABLE reports ADD COLUMN IF NOT EXISTS duplicate_reason VARCHAR(255) NULL");
  await pool.query("ALTER TABLE reports ADD COLUMN IF NOT EXISTS escalated_at TIMESTAMP NULL");
  await pool.query("ALTER TABLE reports ADD COLUMN IF NOT EXISTS progress_percentage TINYINT UNSIGNED NOT NULL DEFAULT 0");
  await pool.query("ALTER TABLE reports ADD COLUMN IF NOT EXISTS ai_severity VARCHAR(30) NULL");
  await pool.query("ALTER TABLE reports ADD COLUMN IF NOT EXISTS ai_analysis VARCHAR(320) NULL");
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
  await pool.query(`CREATE TABLE IF NOT EXISTS advisory_comments (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY, advisory_id INT UNSIGNED NOT NULL,
    author_id INT UNSIGNED NULL, body TEXT NOT NULL, created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT advisory_comments_advisory_fk FOREIGN KEY (advisory_id) REFERENCES advisories(id) ON DELETE CASCADE,
    CONSTRAINT advisory_comments_author_fk FOREIGN KEY (author_id) REFERENCES users(id) ON DELETE SET NULL,
    INDEX advisory_comments_thread_idx (advisory_id, created_at, id)
  ) ENGINE=InnoDB`);
  await pool.query(`CREATE TABLE IF NOT EXISTS advisory_reactions (
    advisory_id INT UNSIGNED NOT NULL, user_id INT UNSIGNED NOT NULL,
    reacted_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (advisory_id, user_id),
    CONSTRAINT advisory_reactions_advisory_fk FOREIGN KEY (advisory_id) REFERENCES advisories(id) ON DELETE CASCADE,
    CONSTRAINT advisory_reactions_user_fk FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
  ) ENGINE=InnoDB`);
  await pool.query(`CREATE TABLE IF NOT EXISTS notifications (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY, user_id INT UNSIGNED NOT NULL, report_id INT UNSIGNED NULL, advisory_id INT UNSIGNED NULL,
    type VARCHAR(50) NOT NULL, title VARCHAR(255) NOT NULL, message TEXT NOT NULL, channel VARCHAR(30) NOT NULL DEFAULT 'push', read_at TIMESTAMP NULL, created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT notifications_user_fk FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE, CONSTRAINT notifications_report_fk FOREIGN KEY (report_id) REFERENCES reports(id) ON DELETE CASCADE,
    CONSTRAINT notifications_advisory_fk FOREIGN KEY (advisory_id) REFERENCES advisories(id) ON DELETE CASCADE
  ) ENGINE=InnoDB`);
  await pool.query("ALTER TABLE notifications ADD COLUMN IF NOT EXISTS channel VARCHAR(30) NOT NULL DEFAULT 'push'");
  await pool.query(`CREATE TABLE IF NOT EXISTS push_device_tokens (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    user_id INT UNSIGNED NOT NULL,
    token VARCHAR(512) CHARACTER SET ascii COLLATE ascii_bin NOT NULL UNIQUE,
    platform VARCHAR(20) NOT NULL DEFAULT 'android',
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT push_device_tokens_user_fk FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    INDEX push_device_tokens_user_idx (user_id)
  ) ENGINE=InnoDB`);
  await pool.query(`CREATE TABLE IF NOT EXISTS user_preferences (
    user_id INT UNSIGNED PRIMARY KEY, allow_notifications BOOLEAN NOT NULL DEFAULT TRUE, show_location_on_reports BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP, CONSTRAINT preferences_user_fk FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
  ) ENGINE=InnoDB`);
  await pool.query(`CREATE TABLE IF NOT EXISTS verification_documents (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY, user_id INT UNSIGNED NOT NULL, document_type VARCHAR(60) NOT NULL,
    document_side VARCHAR(20) NULL,
    file_path VARCHAR(500), status ENUM('pending','approved','rejected') NOT NULL DEFAULT 'pending', reviewed_by INT UNSIGNED NULL,
    reviewed_at TIMESTAMP NULL, created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP, CONSTRAINT verification_user_fk FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    CONSTRAINT verification_reviewer_fk FOREIGN KEY (reviewed_by) REFERENCES users(id) ON DELETE SET NULL
  ) ENGINE=InnoDB`);
  await pool.query("ALTER TABLE verification_documents ADD COLUMN IF NOT EXISTS document_side VARCHAR(20) NULL AFTER document_type");
  await pool.query(`CREATE TABLE IF NOT EXISTS moderation_actions (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY, user_id INT UNSIGNED NOT NULL, admin_id INT UNSIGNED NULL,
    action ENUM('warn','suspend','ban','restore') NOT NULL, reason VARCHAR(160) NOT NULL,
    duration VARCHAR(40), note TEXT, created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT moderation_user_fk FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    CONSTRAINT moderation_admin_fk FOREIGN KEY (admin_id) REFERENCES users(id) ON DELETE SET NULL
  ) ENGINE=InnoDB`);
  await pool.query(`UPDATE users u
    JOIN moderation_actions ma ON ma.user_id = u.id AND ma.action = 'suspend'
    JOIN (
      SELECT user_id, MAX(id) AS action_id
      FROM moderation_actions
      WHERE action = 'suspend'
      GROUP BY user_id
    ) latest ON latest.action_id = ma.id
    SET u.suspended_until = CASE ma.duration
      WHEN '24 hours' THEN DATE_ADD(ma.created_at, INTERVAL 24 HOUR)
      WHEN '3 days' THEN DATE_ADD(ma.created_at, INTERVAL 3 DAY)
      WHEN '7 days' THEN DATE_ADD(ma.created_at, INTERVAL 7 DAY)
      WHEN '14 days' THEN DATE_ADD(ma.created_at, INTERVAL 14 DAY)
      WHEN '30 days' THEN DATE_ADD(ma.created_at, INTERVAL 30 DAY)
      ELSE NULL
    END
    WHERE u.standing = 'Suspended'
      AND u.suspended_until IS NULL
      AND ma.duration IN ('24 hours', '3 days', '7 days', '14 days', '30 days')`);
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
    ["MT-2026-879", "Damaged barangay hall entrance", "Residents report damaged steps at the public building entrance.", "Public Buildings", "Brgy. Dawan", 6.9482, 126.2311, "High", "In progress", "marco.b@example.com"],
    ["MT-2026-884", "Clogged drainage near market", "Drainage blockage near the public market.", "Drainage", "Brgy. Central", 6.9511, 126.2249, "Medium", "Reported", "grace.v@example.com"],
    ["MT-2026-860", "Streetlight repaired, J.P. Laurel", "Streetlight repair completed.", "Streetlights", "Brgy. Sainz", 6.9498, 126.2295, "Low", "Resolved", "rico.f@example.com"],
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
    ["maint", "Streetlight maintenance, Barangay Central", "A maintenance crew will inspect and repair streetlights along the main road today."],
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
  const teams = [
    ["Roads Response Team", "Roads"],
    ["Public Buildings Team", "Public Buildings"],
    ["Streetlight Maintenance Team", "Streetlights"],
    ["Electric Poles Team", "Electric Poles"],
    ["Drainage Crew", "Drainage"],
  ];
  for (const [name, department] of teams) await pool.query("INSERT IGNORE INTO teams (name, department) VALUES (?, ?)", [name, department]);
  await pool.query("UPDATE teams SET active = FALSE WHERE department = 'Water' OR name = 'Water Services Team'");
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
  res.header("Access-Control-Allow-Methods", "GET, POST, PATCH, DELETE, OPTIONS");
  if (req.method === "OPTIONS") return res.sendStatus(204);
  next();
});
async function restoreExpiredSuspension(user) {
  if (user.standing !== "Suspended" || !user.suspended_until) return false;
  const [result] = await pool.query(
    "UPDATE users SET standing = 'Active', suspended_until = NULL WHERE id = ? AND standing = 'Suspended' AND suspended_until <= CURRENT_TIMESTAMP",
    [user.id],
  );
  if (!result.affectedRows) return false;
  await pool.query(
    "INSERT INTO moderation_actions (user_id, admin_id, action, reason) VALUES (?, NULL, 'restore', 'Suspension period ended')",
    [user.id],
  );
  await queueNotification({
    userId: user.id,
    type: "account",
    title: "Reporting access restored",
    message: "Your suspension period has ended. You can submit reports again.",
  });
  user.standing = "Active";
  user.suspended_until = null;
  return true;
}

app.use(async (req, res, next) => {
  const publicMobileRoutes = new Set([
    "/api/mobile/issues",
    "/api/mobile/overview",
    "/api/mobile/advisories",
  ]);
  const isMobileRoute = req.path.startsWith("/api/mobile/");
  const isPublicDiscussionRead =
    req.method === "GET" &&
    /^\/api\/mobile\/issues\/[^/]+\/discussion$/.test(req.path);
  const isPublicAdvisorySocialRead =
    req.method === "GET" &&
    /^\/api\/mobile\/advisories\/\d+\/social$/.test(req.path);
  const isPublicMobileRoute =
    req.method === "GET" &&
    (publicMobileRoutes.has(req.path) ||
      isPublicDiscussionRead ||
      isPublicAdvisorySocialRead);
  const isMobileUpload = req.path === "/api/uploads" && req.method === "POST";
  if (isPublicMobileRoute && !req.headers.authorization) return next();
  if (
    !req.path.startsWith("/api/") ||
    req.path === "/api/health" ||
    req.path === "/api/auth/login" ||
    req.path === "/api/mobile/auth/login" ||
    req.path === "/api/auth/register"
  ) return next();
  const token = String(req.headers.authorization || "").replace(/^Bearer\s+/i, "");
  if (!token) return res.status(401).json({ error: "Authentication required" });
  let user;
  try {
    [[user]] = await pool.query(
      "SELECT u.id, u.name, u.email, u.mobile, u.barangay, u.role, u.standing, u.suspended_until, u.verification, u.created_at FROM admin_sessions s JOIN users u ON u.id = s.user_id WHERE s.token_hash = ? AND s.expires_at > CURRENT_TIMESTAMP",
      [hashSessionToken(token)],
    );
  } catch (error) {
    console.error("Unable to validate API session:", error.message);
    return res.status(503).json({ error: "Database unavailable" });
  }
  if (!user || (!isMobileRoute && !isMobileUpload && !["lgu", "admin", "barangay_staff"].includes(user.role))) {
    return res.status(401).json({ error: "Session expired or invalid" });
  }
  if (isMobileRoute) {
    await pool.query(
      "UPDATE admin_sessions SET expires_at = DATE_ADD(CURRENT_TIMESTAMP, INTERVAL 8 HOUR) WHERE token_hash = ?",
      [hashSessionToken(token)],
    );
  }
  const isMobileClient = isMobileRoute || isMobileUpload;
  if (isMobileClient) await restoreExpiredSuspension(user);
  if (isMobileClient && user.role === "resident" && user.standing === "Banned") {
    await pool.query("DELETE FROM admin_sessions WHERE token_hash = ?", [hashSessionToken(token)]);
    return res.status(403).json({
      code: "ACCOUNT_BANNED",
      error: "This account has been banned from InfraTrack. Contact Mati City support if you believe this is an error.",
    });
  }
  const isReportSubmission =
    (req.method === "POST" && req.path === "/api/mobile/reports") ||
    (req.method === "POST" && req.path === "/api/uploads");
  if (
    isMobileClient &&
    user.role === "resident" &&
    user.standing === "Suspended" &&
    isReportSubmission
  ) {
    return res.status(403).json({
      code: "REPORTING_SUSPENDED",
      error: "Your account is temporarily suspended from submitting reports. You can continue using other parts of InfraTrack.",
      suspendedUntil: user.suspended_until,
    });
  }
  if (
    isMobileClient &&
    user.role === "resident" &&
    user.verification !== "Verified" &&
    (req.method === "POST" && req.path === "/api/mobile/reports" ||
      req.method === "POST" && req.path === "/api/uploads")
  ) {
    return res.status(403).json({
      code: "ACCOUNT_NOT_VERIFIED",
      error: "Your account must be verified before you can submit a report.",
      verification: user.verification,
    });
  }
  req.auth = user;
  req.authToken = token;
  next();
});
app.get("/uploads/:filename", async (req, res, next) => {
  const filename = path.basename(req.params.filename);
  const filePath = path.join(uploadDirectory, filename);
  if (!fs.existsSync(filePath)) return next();

  const extension = path.extname(filename).toLowerCase();
  const contentTypes = {
    ".gif": "image/gif",
    ".jpg": "image/jpeg",
    ".jpeg": "image/jpeg",
    ".png": "image/png",
    ".webp": "image/webp",
    ".mp4": "video/mp4",
    ".mov": "video/quicktime",
    ".webm": "video/webm",
  };
  if (contentTypes[extension]) {
    res.type(contentTypes[extension]);
    return res.sendFile(filePath);
  }

  try {
    const [[media]] = await pool.query(
      `SELECT media_type FROM media WHERE file_path LIKE ?
       UNION ALL
       SELECT media_type FROM advisory_media WHERE file_path LIKE ?
       LIMIT 1`,
      [`%/uploads/${filename}`, `%/uploads/${filename}`],
    );
    const legacyContentTypes = {
      gif: "image/gif",
      photo: "image/jpeg",
      video: "video/mp4",
    };
    if (media?.media_type && legacyContentTypes[media.media_type]) {
      res.type(legacyContentTypes[media.media_type]);
    }
  } catch (error) {
    console.error("Unable to resolve legacy upload media type:", error.message);
  }
  return res.sendFile(filePath);
});
app.use("/uploads", express.static(uploadDirectory, { maxAge: "1h", etag: true }));
async function findDiscussionReport(identifier) {
  const parsedId = /^\d+$/.test(identifier) ? Number(identifier) : -1;
  const numericId = Number.isSafeInteger(parsedId) ? parsedId : -1;
  const [reports] = await pool.query(
    `SELECT r.id, r.public_id, r.title, r.status, r.reporter_id, r.location,
      u.barangay AS reporter_barangay
      FROM reports r
      LEFT JOIN users u ON u.id = r.reporter_id
      WHERE r.public_id = ? OR r.id = ?
      LIMIT 1`,
    [identifier, numericId],
  );
  return reports[0] ?? null;
}

function canAccessReportDiscussion(user, report) {
  return (
    canReplyToReport(user, report) &&
    getReportScope(user).allows(report)
  );
}

function formatDiscussionComment(comment) {
  return {
    id: comment.id,
    body: comment.body,
    author_name: comment.author_name || "Former user",
    author_role: comment.author_role || "staff",
    created_at: comment.created_at,
  };
}

async function insertDiscussionComment(req, res, report) {
  const validationError = validateReportComment(req.body?.body);
  if (validationError) return res.status(400).json({ error: validationError });
  if (!isReportDiscussionOpen(report.status)) {
    return res.status(409).json({
      error: "Replies are closed because this report is no longer unresolved.",
    });
  }

  const body = req.body.body.trim();
  const [result] = await pool.query(
    `INSERT INTO report_comments (report_id, author_id, body, visibility)
      VALUES (?, ?, ?, 'semi-public')`,
    [report.id, req.auth.id, body],
  );
  const [[comment]] = await pool.query(
    `SELECT c.id, c.body, c.created_at, u.name AS author_name, u.role AS author_role
      FROM report_comments c
      LEFT JOIN users u ON u.id = c.author_id
      WHERE c.id = ?`,
    [result.insertId],
  );
  return res.status(201).json({ comment: formatDiscussionComment(comment) });
}

app.get("/api/health", async (_req, res) => {
  try { await pool.query("SELECT 1"); res.json({ ok: true, service: "InfraTrack Admin API", database: dbName }); }
  catch { res.status(503).json({ ok: false, error: "Database unavailable" }); }
});
app.get("/api/mobile/issues/:id/discussion", async (req, res) => {
  const report = await findDiscussionReport(req.params.id);
  if (!report || report.status === "Archived") {
    return res.status(404).json({ error: "Report not found" });
  }
  const [comments] = await pool.query(
    `SELECT c.id, c.body, c.created_at, u.role AS author_role
      FROM report_comments c
      LEFT JOIN users u ON u.id = c.author_id
      WHERE c.report_id = ? AND c.visibility IN ('public', 'semi-public')
      ORDER BY c.created_at DESC, c.id DESC
      LIMIT 100`,
    [report.id],
  );
  res.json({
    comments: comments.reverse().map((comment) => ({
      id: comment.id,
      body: comment.body,
      author_name:
        comment.author_role === "resident" ? "Resident" : "InfraTrack Staff",
      author_role: comment.author_role === "resident" ? "resident" : "staff",
      created_at: comment.created_at,
    })),
  });
});
app.post("/api/mobile/issues/:id/discussion", async (req, res) => {
  const report = await findDiscussionReport(req.params.id);
  if (!report || !canAccessReportDiscussion(req.auth, report)) {
    return res.status(404).json({ error: "Report not found" });
  }
  await insertDiscussionComment(req, res, report);
});
app.get("/api/mobile/issues/:id/rating", async (req, res) => {
  const report = await findDiscussionReport(req.params.id);
  if (!report || !canRateReport(req.auth, report)) {
    return res.status(404).json({
      error: "Ratings are available only for resolved reports you submitted.",
    });
  }
  const [[rating]] = await pool.query(
    `SELECT rating, comment, created_at FROM report_ratings
     WHERE report_id = ? AND user_id = ?`,
    [report.id, req.auth.id],
  );
  res.json({
    rating: rating
      ? {
          rating: Number(rating.rating),
          comment: rating.comment || "",
          created_at: rating.created_at,
        }
      : null,
  });
});
app.post("/api/mobile/issues/:id/rating", async (req, res) => {
  const report = await findDiscussionReport(req.params.id);
  if (!report || !canOwnReportRating(req.auth, report)) {
    return res.status(404).json({ error: "Report not found" });
  }
  if (report.status !== "Resolved") {
    return res.status(409).json({
      error: "You can rate this report after the work is marked resolved.",
    });
  }
  const { rating, comment } = req.body ?? {};
  const validationError = validateReportRating(rating, comment);
  if (validationError) return res.status(400).json({ error: validationError });

  let isNewRating = true;
  try {
    await pool.query(
      `INSERT INTO report_ratings (report_id, user_id, rating, comment)
       VALUES (?, ?, ?, ?)`,
      [report.id, req.auth.id, rating, comment?.trim() || null],
    );
  } catch (error) {
    if (error.code !== "ER_DUP_ENTRY") throw error;
    isNewRating = false;
  }

  const [[savedRating]] = await pool.query(
    `SELECT rating, comment, created_at FROM report_ratings
     WHERE report_id = ? AND user_id = ?`,
    [report.id, req.auth.id],
  );
  res.status(isNewRating ? 201 : 200).json({
    rating: {
      rating: Number(savedRating.rating),
      comment: savedRating.comment || "",
      created_at: savedRating.created_at,
    },
    alreadyRated: !isNewRating,
  });
});
app.get("/api/mobile/issues", async (req, res) => {
  const homeUpdatesOnly = req.query.home_updates_only === "true";
  const verifiedOnly = req.query.verified_only === "true";
  const statusFilter = homeUpdatesOnly
    ? "r.status IN ('Approved', 'Verified by inspector', 'In progress')"
    : verifiedOnly
    ? "r.status IN ('Verified by inspector', 'In progress', 'Resolved')"
    : "r.status <> 'Archived'";
  const [issues] = await pool.query(`SELECT r.public_id, r.title, r.description, r.category,
    r.location, u.barangay AS reporter_barangay, r.latitude, r.longitude, r.severity, r.status,
    r.assigned_team, r.resolution_note, r.progress_percentage, r.created_at, r.updated_at,
    (SELECT m.file_path FROM media m WHERE m.report_id = r.id AND m.media_type <> 'resolution_photo' ORDER BY m.id ASC LIMIT 1) AS media_url,
    (SELECT m.media_type FROM media m WHERE m.report_id = r.id AND m.media_type <> 'resolution_photo' ORDER BY m.id ASC LIMIT 1) AS media_kind,
    (SELECT m.file_path FROM media m WHERE m.report_id = r.id AND m.media_type = 'resolution_photo' ORDER BY m.id DESC LIMIT 1) AS resolution_media_url
    FROM reports r LEFT JOIN users u ON u.id = r.reporter_id
    WHERE ${statusFilter} ORDER BY r.created_at DESC`);
  let progressEvents = [];
  if (issues.length > 0) {
    const publicIds = issues.map((issue) => issue.public_id);
    const [events] = await pool.query(
      `SELECT r.public_id AS report_id, e.status, e.note, e.created_at
       FROM report_events e
       JOIN reports r ON r.id = e.report_id
       WHERE r.public_id IN (?)
       ORDER BY e.created_at DESC, e.id DESC`,
      [publicIds],
    );
    progressEvents = events;
  }
  const issuesWithProgress = attachReportEventsToReports(
    issues.map((issue) => ({ ...issue, id: issue.public_id })),
    progressEvents,
  );
  res.json({ issues: issuesWithProgress.map((issue) => ({
    ...issue,
    media_url: publicMediaUrl(req, issue.media_url),
    resolution_media_url: publicMediaUrl(req, issue.resolution_media_url),
  })) });
});
app.get("/api/mobile/overview", async (_req, res) => {
  const [[summary]] = await pool.query(`SELECT COUNT(*) AS total,
    SUM(status IN ('Reported', 'Verified by inspector')) AS pending,
    SUM(status = 'Resolved') AS resolved,
    ROUND(AVG(CASE WHEN status = 'Resolved' THEN TIMESTAMPDIFF(HOUR, created_at, updated_at) / 24 END), 1) AS avg_resolution_days
    FROM reports WHERE status <> 'Archived'`);
  res.json({
    summary: {
      total: Number(summary.total || 0),
      pending: Number(summary.pending || 0),
      resolved: Number(summary.resolved || 0),
      avgResolutionDays: Number(summary.avg_resolution_days || 0),
      completionRate: summary.total
        ? Math.round((Number(summary.resolved || 0) / Number(summary.total)) * 100)
        : 0,
    },
  });
});
app.get("/api/mobile/advisories", async (req, res) => {
  const scope = req.auth?.barangay
    ? {
        sql: ` AND (
          a.audience = 'All barangays' OR a.barangay = ?
          OR REPLACE(REPLACE(LOWER(a.audience), 'barangay ', ''), 'brgy. ', '')
             = REPLACE(REPLACE(LOWER(?), 'barangay ', ''), 'brgy. ', '')
        )`,
        params: [req.auth.barangay, req.auth.barangay],
      }
    : { sql: " AND a.audience = 'All barangays'", params: [] };
  const [advisories] = await pool.query(`SELECT a.id, a.type, a.title, a.message,
    a.audience, a.barangay, a.published_at, a.created_at,
    am.file_path AS media_url, am.media_type AS media_kind,
    (SELECT COUNT(*) FROM advisory_reactions ar WHERE ar.advisory_id = a.id) AS reaction_count,
    ${req.auth ? "EXISTS (SELECT 1 FROM advisory_reactions mine WHERE mine.advisory_id = a.id AND mine.user_id = ?) " : "0 "}
      AS user_has_reacted
    FROM advisories a LEFT JOIN advisory_media am ON am.advisory_id = a.id
    WHERE a.status = 'published'${scope.sql} ORDER BY a.created_at DESC`,
    [...(req.auth ? [req.auth.id] : []), ...scope.params]);
  res.json({ advisories: advisories.map((advisory) => ({
    ...advisory,
    media_url: publicMediaUrl(req, advisory.media_url),
  })) });
});
function advisoryMobileScope(user, alias = "a") {
  if (!user?.barangay) {
    return { sql: ` AND ${alias}.audience = 'All barangays'`, params: [] };
  }
  return {
    sql: ` AND (
      ${alias}.audience = 'All barangays' OR ${alias}.barangay = ?
      OR REPLACE(REPLACE(LOWER(${alias}.audience), 'barangay ', ''), 'brgy. ', '')
         = REPLACE(REPLACE(LOWER(?), 'barangay ', ''), 'brgy. ', '')
    )`,
    params: [user.barangay, user.barangay],
  };
}

async function findPublicMobileAdvisory(identifier, user) {
  if (!/^\d+$/.test(String(identifier))) return null;
  const scope = advisoryMobileScope(user);
  const [advisories] = await pool.query(
    `SELECT a.id, a.type, a.title, a.message, a.audience, a.barangay,
      a.published_at, a.created_at,
      (SELECT am.file_path FROM advisory_media am
       WHERE am.advisory_id = a.id ORDER BY am.id DESC LIMIT 1) AS media_url,
      (SELECT am.media_type FROM advisory_media am
       WHERE am.advisory_id = a.id ORDER BY am.id DESC LIMIT 1) AS media_kind
     FROM advisories a
     WHERE a.id = ? AND a.status = 'published'${scope.sql}
     LIMIT 1`,
    [Number(identifier), ...scope.params],
  );
  return advisories[0] ?? null;
}

app.get("/api/mobile/advisories/:id/social", async (req, res) => {
  const advisory = await findPublicMobileAdvisory(req.params.id, req.auth);
  if (!advisory) return res.status(404).json({ error: "Advisory not found" });
  const [[reactionSummary]] = await pool.query(
    `SELECT COUNT(*) AS reaction_count,
      ${req.auth ? "EXISTS (SELECT 1 FROM advisory_reactions mine WHERE mine.advisory_id = ? AND mine.user_id = ?) " : "0 "}
        AS user_has_reacted
     FROM advisory_reactions WHERE advisory_id = ?`,
    req.auth
      ? [advisory.id, req.auth.id, advisory.id]
      : [advisory.id],
  );
  const [comments] = await pool.query(
    `SELECT c.id, c.body, c.created_at, u.name AS author_name
     FROM advisory_comments c
     LEFT JOIN users u ON u.id = c.author_id
     WHERE c.advisory_id = ?
     ORDER BY c.created_at DESC, c.id DESC
     LIMIT 100`,
    [advisory.id],
  );
  res.json({
    advisory: {
      ...advisory,
      media_url: publicMediaUrl(req, advisory.media_url),
    },
    reaction_count: Number(reactionSummary.reaction_count || 0),
    user_has_reacted: Boolean(reactionSummary.user_has_reacted),
    comments: comments.reverse().map((comment) => ({
      id: comment.id,
      body: comment.body,
      author_name: comment.author_name || "Former user",
      created_at: comment.created_at,
    })),
  });
});

app.post("/api/mobile/advisories/:id/comments", async (req, res) => {
  const advisory = await findPublicMobileAdvisory(req.params.id, req.auth);
  if (!advisory) return res.status(404).json({ error: "Advisory not found" });
  const body = req.body?.body;
  if (typeof body !== "string" || !body.trim()) {
    return res.status(400).json({ error: "Write a comment before sending." });
  }
  if (body.trim().length > 1000) {
    return res.status(400).json({
      error: "Comments must be 1,000 characters or fewer.",
    });
  }
  const [result] = await pool.query(
    `INSERT INTO advisory_comments (advisory_id, author_id, body)
     VALUES (?, ?, ?)`,
    [advisory.id, req.auth.id, body.trim()],
  );
  const [[comment]] = await pool.query(
    `SELECT c.id, c.body, c.created_at, u.name AS author_name
     FROM advisory_comments c
     LEFT JOIN users u ON u.id = c.author_id
     WHERE c.id = ?`,
    [result.insertId],
  );
  res.status(201).json({
    comment: {
      ...comment,
      author_name: comment.author_name || "Resident",
    },
  });
});

app.post("/api/mobile/advisories/:id/reaction", async (req, res) => {
  const advisory = await findPublicMobileAdvisory(req.params.id, req.auth);
  if (!advisory) return res.status(404).json({ error: "Advisory not found" });

  const connection = await pool.getConnection();
  let transactionStarted = false;
  try {
    await connection.beginTransaction();
    transactionStarted = true;
    const [[existingReaction]] = await connection.query(
      "SELECT advisory_id FROM advisory_reactions WHERE advisory_id = ? AND user_id = ? FOR UPDATE",
      [advisory.id, req.auth.id],
    );
    const liked = !existingReaction;
    if (liked) {
      await connection.query(
        "INSERT INTO advisory_reactions (advisory_id, user_id) VALUES (?, ?)",
        [advisory.id, req.auth.id],
      );
    } else {
      await connection.query(
        "DELETE FROM advisory_reactions WHERE advisory_id = ? AND user_id = ?",
        [advisory.id, req.auth.id],
      );
    }
    const [[summary]] = await connection.query(
      "SELECT COUNT(*) AS reaction_count FROM advisory_reactions WHERE advisory_id = ?",
      [advisory.id],
    );
    await connection.commit();
    transactionStarted = false;
    res.json({
      liked,
      reaction_count: Number(summary.reaction_count || 0),
    });
  } catch (error) {
    if (transactionStarted) await connection.rollback();
    throw error;
  } finally {
    connection.release();
  }
});
app.get("/api/mobile/reports", async (req, res) => {
  const [reports] = await pool.query(`SELECT r.*, u.name AS reporter,
    (SELECT m.file_path FROM media m WHERE m.report_id = r.id ORDER BY m.id ASC LIMIT 1) AS media_url,
    (SELECT m.media_type FROM media m WHERE m.report_id = r.id ORDER BY m.id ASC LIMIT 1) AS media_kind
    FROM reports r LEFT JOIN users u ON u.id = r.reporter_id
    WHERE r.reporter_id = ? ORDER BY r.created_at DESC`, [req.auth.id]);
  let progressEvents = [];
  if (reports.length > 0) {
    const reportIds = reports.map((report) => report.id);
    const [events] = await pool.query(
      `SELECT report_id, status, note, created_at FROM report_events
       WHERE report_id IN (?)
       ORDER BY created_at DESC, id DESC`,
      [reportIds],
    );
    progressEvents = events;
  }
  const reportsWithProgress = attachReportEventsToReports(
    reports,
    progressEvents,
  );
  res.json({ reports: reportsWithProgress.map((report) => ({
    ...report,
    media_url: publicMediaUrl(req, report.media_url),
  })) });
});
app.post("/api/mobile/reports/severity", (req, res) => {
  severityAssessmentUpload.single("evidence")(req, res, async (uploadError) => {
    if (uploadError) {
      const status = uploadError.code === "LIMIT_FILE_SIZE" ? 413 : 400;
      return res.status(status).json({ error: uploadError.message });
    }
    const { description, category, mediaType } = req.body ?? {};
    const normalizedCategory = normalizeReportCategory(category);
    if (!description || !String(description).trim() || !normalizedCategory) {
      return res.status(400).json({
        error: `A report description and valid category are required (${REPORT_CATEGORIES.join(", ")}).`,
      });
    }
    if (req.file && !["photo", "video"].includes(mediaType)) {
      return res.status(400).json({ error: "Invalid severity evidence type." });
    }
    if (!req.file && mediaType) {
      return res.status(400).json({ error: "Severity evidence file is missing." });
    }
    try {
      const assessment = await assessReportSeverity({
        description,
        category: normalizedCategory,
        mediaBuffer: req.file?.buffer ?? null,
        mediaType: req.file ? mediaType : null,
      });
      res.json(assessment);
    } catch (error) {
      if ((error.status ?? 500) >= 500) {
        console.warn("Report severity assessment failed:", error.message);
      }
      res.status(error.status ?? 502).json({
        error: error.message || "Could not assess report severity.",
      });
    }
  });
});
app.post("/api/mobile/reports", async (req, res) => {
  const {
    title,
    description,
    category,
    location,
    latitude,
    longitude,
    severity = "Medium",
    aiSeverity = null,
    aiAnalysis = null,
    mediaUrl,
    mediaType = "photo",
  } = req.body ?? {};
  const normalizedCategory = normalizeReportCategory(category);
  if (!title || !description || !normalizedCategory) {
    return res.status(400).json({ error: `Title, description, and a valid category are required (${REPORT_CATEGORIES.join(", ")})` });
  }
  if (!REPORT_SEVERITIES.includes(severity)) {
    return res.status(400).json({ error: "Choose a valid report severity." });
  }
  if (
    (aiSeverity != null || aiAnalysis != null) &&
    (!REPORT_SEVERITIES.includes(aiSeverity) ||
      typeof aiAnalysis !== "string" ||
      !aiAnalysis.trim() ||
      aiAnalysis.length > 320)
  ) {
    return res.status(400).json({ error: "Provide a valid AI assessment." });
  }
  const [[preferences]] = await pool.query(
    "SELECT show_location_on_reports FROM user_preferences WHERE user_id = ?",
    [req.auth.id],
  );
  const shareLocation = !preferences || Number(preferences.show_location_on_reports) === 1;
  const parsedLat = !shareLocation || latitude == null || latitude === "" ? null : Number(latitude);
  const parsedLng = !shareLocation || longitude == null || longitude === "" ? null : Number(longitude);
  if ((parsedLat == null) !== (parsedLng == null) ||
      (parsedLat != null && (!Number.isFinite(parsedLat) || !Number.isFinite(parsedLng)))) {
    return res.status(400).json({ error: "Provide valid latitude and longitude coordinates" });
  }
  if (parsedLat != null) {
    const boundaryResult = validateBarangayCoordinates({ latitude: parsedLat, longitude: parsedLng, location });
    if (!boundaryResult.valid) return res.status(422).json({ error: boundaryResult.reason });
  }
  let storedMediaUrl = null;
  if (mediaUrl != null) {
    try {
      if (typeof mediaUrl !== "string") throw new Error("Invalid report media URL");
      const origin = `${req.protocol}://${req.get("host")}`;
      const parsedMediaUrl = new URL(mediaUrl, `${origin}/`);
      if (isDurableMediaUrl(mediaUrl)) {
        storedMediaUrl = parsedMediaUrl.toString();
      } else {
        const filename = path.basename(parsedMediaUrl.pathname);
        if (
          parsedMediaUrl.origin !== origin ||
          parsedMediaUrl.pathname !== `/uploads/${filename}` ||
          !fs.existsSync(path.join(uploadDirectory, filename))
        ) {
          throw new Error("Invalid report media URL");
        }
        storedMediaUrl = `${origin}${parsedMediaUrl.pathname}`;
      }
    } catch {
      return res.status(400).json({ error: "Invalid report media URL" });
    }
  }
  if (mediaUrl != null && !["photo", "video", "gif"].includes(mediaType)) {
    return res.status(400).json({ error: "Invalid report media type" });
  }
  const resolvedLocation = !shareLocation
    ? "Mati City"
    : location ||
      (parsedLat != null
      ? validateBarangayCoordinates({ latitude: parsedLat, longitude: parsedLng, location }).matchedBarangay || "Mati City"
      : "Mati City");
  const connection = await pool.getConnection();
  let report;
  try {
    await connection.beginTransaction();
    const id = publicId();
    const [result] = await connection.query(
      "INSERT INTO reports (public_id, title, description, category, location, latitude, longitude, severity, ai_severity, ai_analysis, reporter_id, due_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, DATE_ADD(CURRENT_TIMESTAMP, INTERVAL 3 DAY))",
      [id, title, description, normalizedCategory, resolvedLocation, parsedLat, parsedLng, severity, aiSeverity, aiAnalysis?.trim() ?? null, req.auth.id],
    );
    await connection.query(
      "INSERT INTO report_events (report_id, status, note) VALUES (?, 'Reported', ?)",
      [result.insertId, "Report submitted by resident"],
    );
    if (storedMediaUrl) {
      await connection.query(
        "INSERT INTO media (report_id, file_path, media_type) VALUES (?, ?, ?)",
        [result.insertId, storedMediaUrl, mediaType],
      );
    }
    const [reports] = await connection.query("SELECT * FROM reports WHERE id = ?", [result.insertId]);
    report = reports[0];
    await connection.commit();
  } catch (error) {
    await connection.rollback();
    throw error;
  } finally {
    connection.release();
  }
  const automationResult = await evaluateIssueAutomation(report);
  if (!automationResult.duplicateOf) {
    await notifyIssueStakeholders(report, "newReport");
  }
  await writeAuditLog(req, {
    actorId: req.auth.id,
    action: "report_created",
    resourceType: "report",
    resourceId: report.public_id,
    details: { title, category: normalizedCategory, location: resolvedLocation },
  });
  res.status(201).json({ report });
});
app.get("/api/mobile/notifications", async (req, res) => {
  const [notifications] = await pool.query(
    `SELECT n.id, n.report_id, n.advisory_id, n.type, n.title, n.message,
      n.read_at, n.created_at,
      (SELECT am.file_path FROM advisory_media am
       WHERE am.advisory_id = n.advisory_id
         AND am.media_type IN ('photo', 'gif', 'image')
       ORDER BY am.id DESC LIMIT 1) AS image_url
     FROM notifications n
     WHERE n.user_id = ? ORDER BY n.created_at DESC LIMIT 100`,
    [req.auth.id],
  );
  res.json({
    notifications: notifications.map((notification) => ({
      ...notification,
      image_url: publicMediaUrl(req, notification.image_url),
    })),
  });
});
app.post("/api/mobile/push-tokens", async (req, res) => {
  const token = String(req.body?.token ?? "").trim();
  const platform = String(req.body?.platform ?? "").toLowerCase();
  if (!token || token.length > 512 || platform !== "android") {
    return res.status(400).json({ error: "A valid Android push token is required." });
  }
  await pool.query(
    `INSERT INTO push_device_tokens (user_id, token, platform)
     VALUES (?, ?, ?)
     ON DUPLICATE KEY UPDATE
       user_id = VALUES(user_id),
       platform = VALUES(platform),
       updated_at = CURRENT_TIMESTAMP`,
    [req.auth.id, token, platform],
  );
  res.status(204).end();
});
app.delete("/api/mobile/push-tokens", async (req, res) => {
  const token = String(req.body?.token ?? "").trim();
  if (!token || token.length > 512) {
    return res.status(400).json({ error: "A valid push token is required." });
  }
  await pool.query(
    "DELETE FROM push_device_tokens WHERE user_id = ? AND token = ?",
    [req.auth.id, token],
  );
  res.status(204).end();
});
app.post("/api/mobile/chat", async (req, res) => {
  const messages = normalizeChatRequestMessages(req.body?.messages);
  if (!messages) {
    return res.status(400).json({
      code: "INVALID_CHAT_MESSAGES",
      error:
        "Chat history must include a user message and no user message may exceed 2,000 characters.",
    });
  }

  const now = Date.now();
  const windowMs = 60_000;
  const previousRequests = (chatbotRequests.get(req.auth.id) || []).filter(
    (timestamp) => now - timestamp < windowMs,
  );
  if (previousRequests.length >= 15) {
    chatbotRequests.set(req.auth.id, previousRequests);
    return res.status(429).json({
      code: "CHAT_RATE_LIMITED",
      error: "Please wait a moment before sending another message.",
    });
  }
  previousRequests.push(now);
  chatbotRequests.set(req.auth.id, previousRequests);
  if (chatbotRequests.size > 1000) {
    for (const [userId, timestamps] of chatbotRequests) {
      if (!timestamps.some((timestamp) => now - timestamp < windowMs)) {
        chatbotRequests.delete(userId);
      }
    }
  }

  try {
    const reply = await generateChatReply({ messages });
    res.json({ reply });
  } catch (error) {
    if (error instanceof ChatProviderError) {
      if (error.status >= 500) {
        console.error("Chatbot provider request failed:", error.message);
      }
      const providerFailureDetails = error.providers
        .map(({ provider, status, model }) =>
            `${provider}${model ? ` (${model})` : ""}: ${status == null ? "network error" : `HTTP ${status}`}`)
        .join("; ");
      const hasModelNotFound = error.providers.some(
        ({ status }) => status === 404,
      );
      const hasProviderAuthError = error.providers.some(
        ({ status }) => status === 401 || status === 403,
      );
      const hasProviderRateLimit = error.providers.some(
        ({ status }) => status === 429,
      );
      const providerGuidance = hasModelNotFound
        ? "Check GEMINI_MODEL and GROQ_LLAMA_MODEL in the API environment; the configured model ID may not be available."
        : hasProviderAuthError
          ? "Check the provider API keys and their access permissions in the API environment."
          : hasProviderRateLimit
            ? "A provider rate limit or quota was reached. Check provider usage and quotas."
            : "Check provider keys, quotas, model IDs, and API network access.";
      return res.status(error.status).json({
        code: error.code,
        error:
            error.code === "CHAT_NOT_CONFIGURED"
              ? "The AI assistant is not configured. Add provider keys to the production API environment."
            : error.code === "INVALID_CHAT_MESSAGE"
                ? error.message
                : `AI providers are unavailable (${providerFailureDetails}). ${providerGuidance}`,
      });
    }
    console.error("Unexpected chatbot request failure:", error);
    return res.status(500).json({
      code: "CHAT_REQUEST_FAILED",
      error: "The assistant could not process your message. Please try again.",
    });
  }
});
app.post("/api/mobile/auth/logout", async (req, res) => {
  const pushToken = String(req.body?.pushToken ?? "").trim();
  if (pushToken && pushToken.length <= 512) {
    await pool.query(
      "DELETE FROM push_device_tokens WHERE user_id = ? AND token = ?",
      [req.auth.id, pushToken],
    );
  }
  await pool.query("DELETE FROM admin_sessions WHERE token_hash = ?", [hashSessionToken(req.authToken)]);
  res.status(204).end();
});
app.patch("/api/mobile/notifications/:id/read", async (req, res) => {
  const notificationId = Number(req.params.id);
  if (!Number.isSafeInteger(notificationId) || notificationId <= 0) {
    return res.status(400).json({ error: "Invalid notification ID" });
  }
  const [[notification]] = await pool.query(
    "SELECT id FROM notifications WHERE id = ? AND user_id = ?",
    [notificationId, req.auth.id],
  );
  if (!notification) return res.status(404).json({ error: "Notification not found" });
  await pool.query(
    "UPDATE notifications SET read_at = COALESCE(read_at, CURRENT_TIMESTAMP) WHERE id = ? AND user_id = ?",
    [notificationId, req.auth.id],
  );
  res.json({ ok: true });
});
app.get("/api/mobile/profile", async (req, res) => {
  const [users] = await pool.query(
    "SELECT id, name, email, mobile, barangay, avatar_url, role, standing, suspended_until, verification, created_at FROM users WHERE id = ?",
    [req.auth.id],
  );
  if (!users[0]) return res.status(404).json({ error: "Account not found" });
  users[0].avatar_url = publicMediaUrl(req, users[0].avatar_url);
  res.json({ user: users[0] });
});
app.patch("/api/mobile/profile", async (req, res) => {
  const { name, mobile, barangay } = req.body ?? {};
  if (!name || !String(name).trim()) return res.status(400).json({ error: "Name is required" });
  await pool.query(
    "UPDATE users SET name = ?, mobile = ?, barangay = ? WHERE id = ?",
    [String(name).trim(), String(mobile ?? "").trim(), String(barangay ?? "").trim(), req.auth.id],
  );
  const [users] = await pool.query(
    "SELECT id, name, email, mobile, barangay, avatar_url, role, standing, suspended_until, verification, created_at FROM users WHERE id = ?",
    [req.auth.id],
  );
  users[0].avatar_url = publicMediaUrl(req, users[0].avatar_url);
  req.auth = { ...req.auth, ...users[0] };
  res.json({ user: users[0] });
});
app.post(
  "/api/mobile/profile/photo",
  (req, res, next) => {
    profilePhotoUpload.single("photo")(req, res, (error) => {
      if (error) {
        const status = error.code === "LIMIT_FILE_SIZE" ? 413 : 400;
        return res.status(status).json({
          error:
            error.code === "LIMIT_FILE_SIZE"
              ? "Profile photos must be 8 MB or smaller."
              : error.message,
        });
      }
      next();
    });
  },
  async (req, res) => {
    if (!req.file) {
      return res.status(400).json({ error: "Choose a profile photo to upload." });
    }

    try {
      const cloudinaryUrl = await uploadToCloudinary(
        req.file,
        "infratrack/profile-photos",
      );
      if (process.env.VERCEL && !cloudinaryUrl) {
        await removeTemporaryUpload(req.file);
        return res.status(503).json({
          error:
            "Persistent profile-photo storage is not configured for this deployment.",
        });
      }
      const avatarUrl =
        cloudinaryUrl || `${req.protocol}://${req.get("host")}/uploads/${req.file.filename}`;
      if (cloudinaryUrl) await removeTemporaryUpload(req.file);
      await pool.query("UPDATE users SET avatar_url = ? WHERE id = ?", [
        avatarUrl,
        req.auth.id,
      ]);
      const [users] = await pool.query(
        "SELECT id, name, email, mobile, barangay, avatar_url, role, standing, suspended_until, verification, created_at FROM users WHERE id = ?",
        [req.auth.id],
      );
      users[0].avatar_url = publicMediaUrl(req, users[0].avatar_url);
      req.auth = { ...req.auth, ...users[0] };
      res.json({ user: users[0] });
    } catch (error) {
      await removeTemporaryUpload(req.file);
      console.error("Unable to save profile photo:", error.message);
      res.status(502).json({
        error: `Could not save the profile photo: ${error.message}`,
      });
    }
  },
);
app.get("/api/mobile/preferences", async (req, res) => {
  await pool.query("INSERT IGNORE INTO user_preferences (user_id) VALUES (?)", [req.auth.id]);
  const [preferences] = await pool.query(
    "SELECT allow_notifications, show_location_on_reports FROM user_preferences WHERE user_id = ?",
    [req.auth.id],
  );
  res.json({
    preferences: {
      allowNotifications: Number(preferences[0].allow_notifications) === 1,
      showLocationOnReports: Number(preferences[0].show_location_on_reports) === 1,
    },
  });
});
app.patch("/api/mobile/preferences", async (req, res) => {
  const { allowNotifications, showLocationOnReports } = req.body ?? {};
  if (typeof allowNotifications !== "boolean" || typeof showLocationOnReports !== "boolean") {
    return res.status(400).json({ error: "Both privacy preference values must be provided" });
  }
  await pool.query(
    `INSERT INTO user_preferences (user_id, allow_notifications, show_location_on_reports)
     VALUES (?, ?, ?)
     ON DUPLICATE KEY UPDATE allow_notifications = VALUES(allow_notifications),
       show_location_on_reports = VALUES(show_location_on_reports)`,
    [req.auth.id, allowNotifications, showLocationOnReports],
  );
  res.json({
    preferences: { allowNotifications, showLocationOnReports },
  });
});
app.patch("/api/mobile/profile/password", async (req, res) => {
  const { currentPassword, newPassword } = req.body ?? {};
  if (!currentPassword || !newPassword || String(newPassword).length < 8) {
    return res.status(400).json({ error: "New password must be at least 8 characters" });
  }
  const [[user]] = await pool.query(
    "SELECT id, name, email, password_hash FROM users WHERE id = ?",
    [req.auth.id],
  );
  if (!user || !verifyPassword(String(currentPassword), user.password_hash)) {
    return res.status(400).json({ error: "Current password is incorrect" });
  }
  await pool.query(
    "UPDATE users SET password_hash = ? WHERE id = ?",
    [hashPassword(String(newPassword)), user.id],
  );
  await pool.query(
    "DELETE FROM admin_sessions WHERE user_id = ? AND token_hash <> ?",
    [user.id, hashSessionToken(req.authToken)],
  );
  await writeAuditLog(req, {
    actorId: user.id,
    action: "password_changed",
    resourceType: "account",
    resourceId: user.id,
  });
  res.json({ ok: true });
});
async function handleLogin(req, res, { requireRecaptcha, auditAction }) {
  const { email, password, recaptchaToken } = req.body ?? {};
  const ip = clientIp(req);
  const now = Date.now();
  const attempt = loginAttempts.get(ip) || { count: 0, resetAt: now + 15 * 60 * 1000 };
  if (now > attempt.resetAt) { attempt.count = 0; attempt.resetAt = now + 15 * 60 * 1000; }
  if (attempt.count >= loginMaxAttempts || isAutomatedUserAgent(req)) {
    await writeAuditLog(req, { action: "login_blocked", resourceType: "authentication", details: { reason: isAutomatedUserAgent(req) ? "automated_user_agent" : "rate_limit", email: String(email ?? "").trim() } });
    return res.status(429).json({ error: "Too many or automated login attempts. Please try again later." });
  }
  if (requireRecaptcha) {
    const captcha = await verifyRecaptcha(recaptchaToken, ip);
    if (!captcha.ok) {
      attempt.count += 1;
      loginAttempts.set(ip, attempt);
      await writeAuditLog(req, { action: "login_blocked", resourceType: "authentication", details: { reason: "recaptcha_failed", email: String(email ?? "").trim() } });
      return res.status(403).json({ error: "Security verification failed. Please try again." });
    }
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
  await restoreExpiredSuspension(user);
  if (user.role === "resident" && user.standing === "Banned") {
    await writeAuditLog(req, {
      action: "login_blocked",
      resourceType: "authentication",
      details: { reason: "account_banned", email: user.email },
      actor: user,
    });
    return res.status(403).json({
      code: "ACCOUNT_BANNED",
      error: "This account has been banned from InfraTrack. Contact Mati City support if you believe this is an error.",
    });
  }
  if (!user.password_hash.startsWith("scrypt$")) {
    await pool.query("UPDATE users SET password_hash = ? WHERE id = ?", [hashPassword(String(password ?? "")), user.id]);
  }
  const sessionToken = createSessionToken();
  await pool.query("INSERT INTO admin_sessions (token_hash, user_id, expires_at) VALUES (?, ?, DATE_ADD(CURRENT_TIMESTAMP, INTERVAL 8 HOUR))", [hashSessionToken(sessionToken), user.id]);
  await writeAuditLog(req, { action: auditAction, resourceType: "authentication", actor: user });
  res.json({ token: sessionToken, user: serializeAdminAuthUser(user, publicMediaUrl(req, user.avatar_url)) });
}
app.post("/api/auth/login", (req, res) => handleLogin(req, res, { requireRecaptcha: true, auditAction: "login" }));
app.post("/api/mobile/auth/login", (req, res) => handleLogin(req, res, { requireRecaptcha: false, auditAction: "mobile_login" }));
app.post("/api/auth/logout", async (req, res) => {
  const token = String(req.headers.authorization || "").replace(/^Bearer\s+/i, "");
  if (token) await pool.query("DELETE FROM admin_sessions WHERE token_hash = ?", [hashSessionToken(token)]);
  res.status(204).end();
});
app.patch("/api/account/password", async (req, res) => {
  const { currentPassword, newPassword } = req.body ?? {};
  if (!currentPassword || !newPassword || String(newPassword).length < 8) return res.status(400).json({ error: "New password must be at least 8 characters" });
  const [[user]] = await pool.query("SELECT id, name, email, password_hash FROM users WHERE id = ?", [req.auth.id]);
  if (!user || !verifyPassword(String(currentPassword), user.password_hash)) return res.status(400).json({ error: "Current password is incorrect" });
  await pool.query("UPDATE users SET password_hash = ? WHERE id = ?", [hashPassword(String(newPassword)), user.id]);
  await writeAuditLog(req, { actorId: user.id, action: "password_changed", resourceType: "account", resourceId: user.id });
  const emailNotification = await notifyPasswordChanged(user);
  res.json({ ok: true, emailNotification });
});
app.get("/api/audit-logs", async (req, res) => {
  const admin = req.auth;
  if (!admin || !["lgu", "admin", "barangay_staff"].includes(admin.role)) return res.status(403).json({ error: "Administrator access required" });
  const requestedLimit = Number(req.query.limit);
  const limit = Number.isFinite(requestedLimit) && requestedLimit > 0
    ? Math.min(Math.floor(requestedLimit), 500)
    : 100;
  const requestedOffset = Number(req.query.offset);
  const offset = Number.isFinite(requestedOffset) && requestedOffset > 0
    ? Math.floor(requestedOffset)
    : 0;
  const conditions = [];
  const params = [];
  if (admin.role === "barangay_staff") { conditions.push("actor_barangay = ?"); params.push(admin.barangay); }
  if (req.query.user) { conditions.push("(actor_name LIKE ? OR actor_email LIKE ?)"); params.push(`%${req.query.user}%`, `%${req.query.user}%`); }
  if (req.query.action) { conditions.push("action = ?"); params.push(String(req.query.action)); }
  if (req.query.barangay && admin.role !== "barangay_staff") { conditions.push("actor_barangay = ?"); params.push(String(req.query.barangay)); }
  if (req.query.from) { conditions.push("created_at >= ?"); params.push(`${req.query.from} 00:00:00`); }
  if (req.query.to) { conditions.push("created_at <= ?"); params.push(`${req.query.to} 23:59:59`); }
  const logScope = conditions.length ? ` WHERE ${conditions.join(" AND ")}` : "";
  const [[count]] = await pool.query(
    `SELECT COUNT(*) AS total FROM audit_logs${logScope}`,
    params,
  );
  const [logs] = await pool.query(
    `SELECT id, actor_id, actor_name, actor_email, actor_barangay, actor_role, action, resource_type, resource_id, details, ip_address, created_at FROM audit_logs${logScope} ORDER BY created_at DESC, id DESC LIMIT ? OFFSET ?`,
    [...params, limit, offset],
  );
  res.json({ logs, total: Number(count.total), limit, offset });
});
app.get("/api/ip-location/:ip", async (req, res) => {
  const ip = normalizeClientIp(req.params.ip);
  if (ip === "unknown") return res.status(400).json({ error: "Invalid IP address" });
  if (!isPublicIp(ip)) return res.json({ available: false, reason: "Private or local IP address" });
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 5000);
  try {
    const response = await fetch(`https://ipwho.is/${encodeURIComponent(ip)}`, { signal: controller.signal });
    const data = await response.json();
    if (!response.ok || data.success === false) return res.status(502).json({ error: data.message || "IP location provider unavailable" });
    res.json({
      available: true,
      ip,
      source: "ipwho.is",
      latitude: Number(data.latitude),
      longitude: Number(data.longitude),
      city: data.city || null,
      region: data.region || null,
      country: data.country || null,
      isp: data.connection?.isp || data.isp || null,
      org: data.connection?.org || data.org || null,
    });
  } catch (error) {
    console.error("Unable to retrieve IP location:", error.message);
    res.status(502).json({ error: "IP location provider unavailable" });
  } finally {
    clearTimeout(timeout);
  }
});
app.get("/api/settings", async (req, res) => {
  const viewer = req.auth;
  if (!viewer || !canManageSystemSettings(viewer.role)) return res.status(403).json({ error: "LGU administrator access required" });
  res.json({ settings: await readSystemSettings() });
});
app.patch("/api/settings", async (req, res) => {
  const { settings } = req.body ?? {};
  const viewer = req.auth;
  if (!viewer || !canManageSystemSettings(viewer.role)) return res.status(403).json({ error: "LGU administrator access required" });
  const validation = validateSystemSettingsUpdate(settings);
  if (!validation.valid) return res.status(400).json({ error: validation.error });
  for (const [key, value] of Object.entries(validation.settings)) {
    await pool.query(
      "INSERT INTO system_settings (setting_key, setting_value, updated_by) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE setting_value = VALUES(setting_value), updated_by = VALUES(updated_by)",
      [key, JSON.stringify(value), viewer.id],
    );
  }
  await writeAuditLog(req, { actorId: viewer.id, action: "settings_updated", resourceType: "system_settings", details: validation.settings });
  res.json({ ok: true, settings: await readSystemSettings() });
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
  const reportScope = getReportScope(req.auth, "r");
  const issueWhere = reportScope.sql ? ` WHERE r.status <> 'Archived'${reportScope.sql}` : "";
  const residentScope = getResidentScope(req.auth, "u.barangay");
  const [rows] = req.params.type === "issues"
    ? await pool.query(`SELECT r.public_id, r.title, r.category, r.location, r.severity, r.status, u.name AS reporter, r.created_at FROM reports r LEFT JOIN users u ON u.id = r.reporter_id${issueWhere} ORDER BY r.created_at DESC`, reportScope.params)
    : await pool.query(`SELECT u.name, u.email, u.barangay, u.standing, u.verification, u.created_at FROM users u WHERE u.role = 'resident'${residentScope.sql} ORDER BY u.created_at DESC`, residentScope.params);
  const headers = req.params.type === "issues" ? ["Public ID", "Title", "Category", "Barangay", "Severity", "Status", "Reporter", "Created"] : ["Name", "Email", "Barangay", "Standing", "Verification", "Created"];
  const values = rows.map((row) => Object.values(row).map(csvValue).join(","));
  await writeAuditLog(req, { actorId: req.auth.id, action: `export_${req.params.type}`, resourceType: req.params.type, details: { count: rows.length } });
  res.type("text/csv").set("Content-Disposition", `attachment; filename=infratrack-${req.params.type}.csv`).send([headers.map(csvValue).join(","), ...values].join("\n"));
});
app.post("/api/auth/register", async (req, res) => {
  const { name, email, mobile, barangay, password } = req.body ?? {};
  if (!name || !email || !password) return res.status(400).json({ error: "Name, email, and password are required" });
  const connection = await pool.getConnection();
  let transactionStarted = false;
  try {
    await connection.beginTransaction();
    transactionStarted = true;
    const [result] = await connection.query(
      "INSERT INTO users (name, email, mobile, barangay, password_hash) VALUES (?, ?, ?, ?, ?)",
      [name.trim(), email.trim().toLowerCase(), mobile ?? "", barangay ?? "Mati City", hashPassword(password)],
    );
    const sessionToken = createSessionToken();
    await connection.query(
      "INSERT INTO admin_sessions (token_hash, user_id, expires_at) VALUES (?, ?, DATE_ADD(CURRENT_TIMESTAMP, INTERVAL 8 HOUR))",
      [hashSessionToken(sessionToken), result.insertId],
    );
    await connection.commit();
    res.status(201).json({
      token: sessionToken,
      user: { id: result.insertId, name: name.trim(), email: email.trim().toLowerCase(), mobile: mobile ?? "", barangay: barangay ?? "Mati City", role: "resident" },
    });
  } catch (error) {
    if (transactionStarted) await connection.rollback();
    if (error.code === "ER_DUP_ENTRY") return res.status(409).json({ error: "An account with this email already exists" });
    res.status(500).json({ error: "Could not create account" });
  } finally {
    connection.release();
  }
});
app.get("/api/issues/:id/discussion", async (req, res) => {
  const report = await findDiscussionReport(req.params.id);
  if (!report || !canAccessReportDiscussion(req.auth, report)) {
    return res.status(404).json({ error: "Report not found" });
  }
  const [comments] = await pool.query(
    `SELECT c.id, c.body, c.created_at, u.name AS author_name, u.role AS author_role
      FROM report_comments c
      LEFT JOIN users u ON u.id = c.author_id
      WHERE c.report_id = ? AND c.visibility IN ('public', 'semi-public')
      ORDER BY c.created_at DESC, c.id DESC
      LIMIT 100`,
    [report.id],
  );
  res.json({ comments: comments.reverse().map(formatDiscussionComment) });
});
app.get("/api/issues/:id/ratings", async (req, res) => {
  const report = await findDiscussionReport(req.params.id);
  if (!report || !getReportScope(req.auth).allows(report)) {
    return res.status(404).json({ error: "Report not found" });
  }
  const [ratings] = await pool.query(
    `SELECT rr.rating, rr.comment, rr.created_at, u.name AS reviewer_name
     FROM report_ratings rr
     LEFT JOIN users u ON u.id = rr.user_id
     WHERE rr.report_id = ?
     ORDER BY rr.created_at DESC`,
    [report.id],
  );
  res.json({
    ratings: ratings.map((rating) => ({
      rating: Number(rating.rating),
      comment: rating.comment || "",
      reviewer_name: rating.reviewer_name || "Resident",
      created_at: rating.created_at,
    })),
  });
});
app.post("/api/issues/:id/discussion", async (req, res) => {
  const report = await findDiscussionReport(req.params.id);
  if (!report || !canAccessReportDiscussion(req.auth, report)) {
    return res.status(404).json({ error: "Report not found" });
  }
  await insertDiscussionComment(req, res, report);
});
app.get("/api/issues", async (req, res) => {
  const search = `%${String(req.query.search ?? "").toLowerCase()}%`;
  const scope = getReportScope(req.auth, "r");
  const [issues] = await pool.query(`SELECT r.*, u.name AS reporter, u.barangay AS reporter_barangay,
    EXISTS (
      SELECT 1 FROM reports duplicate_report
      WHERE duplicate_report.id = r.duplicate_of
        AND duplicate_report.reporter_id = r.reporter_id
        AND r.reporter_id IS NOT NULL
    ) AS same_reporter_duplicate,
    (SELECT m.file_path FROM media m WHERE m.report_id = r.id AND m.media_type <> 'resolution_photo' ORDER BY m.id ASC LIMIT 1) AS media_url,
    (SELECT m.media_type FROM media m WHERE m.report_id = r.id AND m.media_type <> 'resolution_photo' ORDER BY m.id ASC LIMIT 1) AS media_kind,
    (SELECT m.file_path FROM media m WHERE m.report_id = r.id AND m.media_type = 'resolution_photo' ORDER BY m.id DESC LIMIT 1) AS resolution_media_url,
    (SELECT COUNT(*) FROM media m WHERE m.report_id = r.id AND m.media_type <> 'resolution_photo') AS media_count,
    (SELECT COUNT(*) FROM media m WHERE m.report_id = r.id AND m.media_type IN ('photo', 'gif')) AS photo_count,
    (SELECT COUNT(*) FROM media m WHERE m.report_id = r.id AND m.media_type = 'video') AS video_count,
    (SELECT e.note FROM report_events e WHERE e.report_id = r.id ORDER BY e.created_at DESC, e.id DESC LIMIT 1) AS latest_event_note,
    (SELECT e.created_at FROM report_events e WHERE e.report_id = r.id ORDER BY e.created_at DESC, e.id DESC LIMIT 1) AS latest_event_at
    FROM reports r LEFT JOIN users u ON u.id = r.reporter_id
    WHERE r.status <> 'Archived' AND LOWER(CONCAT(r.title, ' ', r.location, ' ', r.public_id)) LIKE ?${scope.sql}
    ORDER BY r.created_at DESC`, [search, ...scope.params]);
  res.json({
    issues: issues.map((issue) => ({
      ...issue,
      media_url: publicMediaUrl(req, issue.media_url),
      resolution_media_url: publicMediaUrl(req, issue.resolution_media_url),
    })),
  });
});
app.get("/api/overview", async (req, res) => {
  const viewer = req.auth;
  const reportScope = getReportScope(viewer, "reports");
  const scope = reportScope.sql;
  const scopeParams = reportScope.params;
  const [[summary]] = await pool.query(`SELECT COUNT(*) AS total,
    SUM(status IN ('Reported', 'Verified by inspector')) AS pending,
    SUM(status = 'Resolved') AS resolved,
    ROUND(AVG(CASE WHEN status = 'Resolved' THEN TIMESTAMPDIFF(HOUR, created_at, updated_at) / 24 END), 1) AS avg_resolution_days
    FROM reports WHERE status <> 'Archived'${scope}`, scopeParams);
  const [categoryRows] = await pool.query(`SELECT category AS name, COUNT(*) AS count FROM reports WHERE status <> 'Archived'${scope} GROUP BY category ORDER BY count DESC`, scopeParams);
  const categories = aggregateReportCategories(categoryRows);
  const categoriesTotal = categories.reduce((total, item) => total + item.count, 0);
  const [teams] = await pool.query(`SELECT COALESCE(NULLIF(assigned_team, ''), 'Unassigned') AS name,
    COUNT(*) AS active_count FROM reports
    WHERE status NOT IN ('Resolved', 'Rejected', 'Archived')${scope} GROUP BY COALESCE(NULLIF(assigned_team, ''), 'Unassigned') ORDER BY active_count DESC LIMIT 6`, scopeParams);
  const [recent] = await pool.query(`SELECT public_id, title, status, category, location, created_at
    FROM reports WHERE status <> 'Archived'${scope} ORDER BY created_at DESC LIMIT 5`, scopeParams);
  res.json({
    summary: { total: Number(summary.total || 0), pending: Number(summary.pending || 0), resolved: Number(summary.resolved || 0), avgResolutionDays: Number(summary.avg_resolution_days || 0), completionRate: summary.total ? Math.round((Number(summary.resolved || 0) / Number(summary.total)) * 100) : 0 },
    categories: categories.map((item) => ({ name: item.name, count: item.count, percentage: categoriesTotal ? Math.round((item.count / categoriesTotal) * 100) : 0 })),
    teams: teams.map((item) => ({ name: item.name, activeCount: Number(item.active_count) })),
    recent,
  });
});
app.get("/api/analytics", async (req, res) => {
  const period = ["day", "week", "month", "year"].includes(req.query.period) ? req.query.period : "month";
  const settings = {
    day: { interval: "1 DAY", format: "%Y-%m-%d %H:00", label: "Last 24 hours" },
    week: { interval: "7 DAY", format: "%Y-%m-%d", label: "Last 7 days" },
    month: { interval: "30 DAY", format: "%Y-%m-%d", label: "Last 30 days" },
    year: { interval: "12 MONTH", format: "%Y-%m", label: "Last 12 months" },
  }[period];
  const viewer = req.auth;
  const reportScope = getReportScope(viewer, "r");
  const where = `r.created_at >= DATE_SUB(NOW(), INTERVAL ${settings.interval})${reportScope.sql}`;
  const whereParams = reportScope.params;
  const [[summary]] = await pool.query(`SELECT COUNT(*) AS total,
    SUM(status = 'Reported') AS reported, SUM(status = 'In progress') AS in_progress,
    SUM(status = 'Resolved') AS resolved FROM reports r WHERE ${where}`, whereParams);
  const [categoryRows] = await pool.query(`SELECT r.category AS name, COUNT(*) AS count FROM reports r WHERE ${where} GROUP BY r.category ORDER BY count DESC`, whereParams);
  const categories = aggregateReportCategories(categoryRows);
  const [reportsForThemes] = await pool.query(`SELECT r.title, r.description, r.category FROM reports r WHERE ${where}`, whereParams);
  const reportThemes = analyzeReportThemes(reportsForThemes);
  const [hotspots] = await pool.query(`SELECT location_reports.name,
    SUM(location_reports.category_count) AS count,
    GROUP_CONCAT(location_reports.category ORDER BY location_reports.category_count DESC SEPARATOR ', ') AS categories
    FROM (
      SELECT COALESCE(NULLIF(TRIM(r.location), ''), 'Location not specified') AS name,
        r.category, COUNT(*) AS category_count
      FROM reports r
      WHERE ${where}
      GROUP BY COALESCE(NULLIF(TRIM(r.location), ''), 'Location not specified'), r.category
    ) AS location_reports
    GROUP BY location_reports.name
    ORDER BY count DESC
    LIMIT 5`, whereParams);
  const [trend] = await pool.query(`SELECT DATE_FORMAT(r.created_at, ?) AS label, COUNT(*) AS count FROM reports r WHERE ${where} GROUP BY label ORDER BY label`, [settings.format, ...whereParams]);
  const [[ratings]] = await pool.query(`SELECT ROUND(AVG(rr.rating), 1) AS average, COUNT(*) AS total FROM report_ratings rr JOIN reports r ON r.id = rr.report_id WHERE rr.created_at >= DATE_SUB(NOW(), INTERVAL ${settings.interval})${reportScope.sql}`, whereParams);
  res.json({ period, periodLabel: settings.label, summary: { total: Number(summary.total || 0), reported: Number(summary.reported || 0), inProgress: Number(summary.in_progress || 0), resolved: Number(summary.resolved || 0) }, categories, themes: reportThemes, hotspots, trend, ratings: { average: Number(ratings.average || 0), total: Number(ratings.total || 0) } });
});
app.get("/api/users", async (req, res) => {
  const viewer = req.auth;
  const residentScope = getResidentScope(viewer, "u.barangay");
  const [users] = await pool.query(`SELECT u.id, u.name, u.email, u.barangay, u.standing, u.suspended_until, u.verification,
    DATE_FORMAT(u.created_at, '%b %Y') AS joined, COUNT(DISTINCT r.id) AS reports,
    MAX(CASE WHEN vd.document_type = 'selfie' THEN vd.file_path END) AS selfie_path,
    MAX(CASE WHEN vd.document_side = 'front' THEN vd.file_path END) AS id_front_path,
    MAX(CASE WHEN vd.document_side = 'back' THEN vd.file_path END) AS id_back_path,
    MAX(CASE WHEN vd.document_side IS NULL AND vd.document_type <> 'selfie' THEN vd.file_path END) AS legacy_id_path,
    MAX(CASE WHEN vd.document_side = 'front' OR (vd.document_side IS NULL AND vd.document_type <> 'selfie') THEN vd.document_type END) AS id_type
    FROM users u
    LEFT JOIN reports r ON r.reporter_id = u.id
    LEFT JOIN verification_documents vd ON vd.user_id = u.id
    WHERE u.role = 'resident'${residentScope.sql}
    GROUP BY u.id ORDER BY u.created_at DESC`, residentScope.params);
  for (const user of users) {
    user.selfie_url = publicMediaUrl(req, user.selfie_path);
    user.id_front_url = publicMediaUrl(req, user.id_front_path || user.legacy_id_path);
    user.id_back_url = publicMediaUrl(req, user.id_back_path);
    delete user.selfie_path;
    delete user.id_front_path;
    delete user.id_back_path;
    delete user.legacy_id_path;
  }
  res.json({ users });
});

app.get("/api/users/:id/reports", async (req, res) => {
  const userId = Number(req.params.id);
  if (!Number.isInteger(userId) || userId < 1) {
    return res.status(400).json({ error: "A valid resident account is required." });
  }
  const [[resident]] = await pool.query(
    "SELECT id, barangay FROM users WHERE id = ? AND role = 'resident'",
    [userId],
  );
  if (!resident) return res.status(404).json({ error: "Resident account not found." });
  if (!getResidentScope(req.auth).allows(resident)) {
    return res.status(403).json({ error: "You can only view residents in your barangay." });
  }

  const [reports] = await pool.query(
    `SELECT public_id, title, category, location, status, created_at
      FROM reports WHERE reporter_id = ? ORDER BY created_at DESC LIMIT 5`,
    [resident.id],
  );
  res.json({ reports });
});

app.post("/api/mobile/verification-documents", (req, res, next) => {
  upload.fields([
    { name: "idFrontImage", maxCount: 1 },
    { name: "idBackImage", maxCount: 1 },
    { name: "selfieImage", maxCount: 1 },
  ])(req, res, async (error) => {
    if (error) {
      return res.status(400).json({ error: error.message || "Could not upload verification images." });
    }
    try {
      const idFrontFile = req.files?.idFrontImage?.[0];
      const idBackFile = req.files?.idBackImage?.[0];
      const selfieFile = req.files?.selfieImage?.[0];
      if (!idFrontFile || !idBackFile || !selfieFile) {
        return res.status(400).json({ error: "Both sides of the government ID and the live selfie are required." });
      }
      if (process.env.VERCEL && !hasCloudinaryStorage && !hasSignedCloudinaryStorage) {
        return res.status(503).json({
          error: "Media storage is not configured. Set Cloudinary storage variables before submitting verification documents.",
        });
      }
      const idFrontUrl = await uploadToCloudinary(idFrontFile);
      const idBackUrl = await uploadToCloudinary(idBackFile);
      const selfieUrl = await uploadToCloudinary(selfieFile);
      if (idFrontUrl) await removeTemporaryUpload(idFrontFile);
      if (idBackUrl) await removeTemporaryUpload(idBackFile);
      if (selfieUrl) await removeTemporaryUpload(selfieFile);
      const storedIdFrontUrl = idFrontUrl || `/uploads/${idFrontFile.filename}`;
      const storedIdBackUrl = idBackUrl || `/uploads/${idBackFile.filename}`;
      const storedSelfieUrl = selfieUrl || `/uploads/${selfieFile.filename}`;
      const documentType = String(req.body?.documentType || "identity_document").trim().slice(0, 60);
      const verification = "Pending ID match";
      const connection = await pool.getConnection();
      try {
        await connection.beginTransaction();
        await connection.query(
          "DELETE FROM verification_documents WHERE user_id = ?",
          [req.auth.id],
        );
        await connection.query(
          "INSERT INTO verification_documents (user_id, document_type, document_side, file_path) VALUES (?, ?, 'front', ?), (?, ?, 'back', ?), (?, 'selfie', 'selfie', ?)",
          [req.auth.id, documentType, storedIdFrontUrl, req.auth.id, documentType, storedIdBackUrl, req.auth.id, storedSelfieUrl],
        );
        await connection.query(
          "UPDATE users SET verification = ? WHERE id = ?",
          [verification, req.auth.id],
        );
        await connection.commit();
      } catch (databaseError) {
        await connection.rollback();
        throw databaseError;
      } finally {
        connection.release();
      }
      res.status(201).json({ ok: true, verification });
    } catch (routeError) {
      next(routeError);
    }
  });
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
    const staff = { id: result.insertId, name: name.trim(), email: email.trim().toLowerCase(), barangay: barangay.trim(), role, standing: "Active" };
    const emailNotification = await notifyStaffAccountReady(staff);
    res.status(201).json({ staff, emailNotification });
  } catch (error) {
    if (error.code === "ER_DUP_ENTRY") return res.status(409).json({ error: "An account with this email already exists" });
    res.status(500).json({ error: "Could not create staff account" });
  }
});
app.patch("/api/staff/:id", async (req, res) => {
  if (!["lgu", "admin"].includes(req.auth.role)) return res.status(403).json({ error: "LGU administrator access required" });
  const { name, email, barangay, standing, role, password } = req.body ?? {};
  if (password && password.length < 8) return res.status(400).json({ error: "Password must be at least 8 characters" });
  const [rows] = await pool.query("SELECT id, name, email, role FROM users WHERE id = ? AND role IN ('barangay_staff', 'lgu', 'admin')", [Number(req.params.id)]);
  if (!rows[0]) return res.status(404).json({ error: "Staff account not found" });
  if (role && !["barangay_staff", "lgu"].includes(role)) return res.status(400).json({ error: "Invalid staff role" });
  await pool.query("UPDATE users SET name = COALESCE(?, name), email = COALESCE(?, email), barangay = COALESCE(?, barangay), standing = COALESCE(?, standing), role = COALESCE(?, role), password_hash = COALESCE(?, password_hash) WHERE id = ?", [name?.trim() || null, email?.trim().toLowerCase() || null, barangay?.trim() || null, standing || null, role || null, password && password.length >= 8 ? hashPassword(password) : null, Number(req.params.id)]);
  await writeAuditLog(req, { actorId: req.auth.id, action: password ? "staff_updated_password" : standing === "Disabled" ? "staff_disabled" : "staff_updated", resourceType: "user", resourceId: req.params.id, details: { name, email, barangay, standing, role } });
  const [[staff]] = await pool.query("SELECT id, name, email, barangay, role, standing, verification FROM users WHERE id = ?", [Number(req.params.id)]);
  const emailNotification = password ? await notifyPasswordChanged(rows[0], true) : undefined;
  res.json({ staff, ...(emailNotification ? { emailNotification } : {}) });
});
app.get("/api/advisories", async (req, res) => {
  const status = req.query.status || "published";
  const scope = getAdvisoryReadScope(req.auth, "a");
  const [advisories] = await pool.query(`SELECT a.*, u.name AS author,
    am.file_path AS media_url, am.media_type AS media_kind
    FROM advisories a LEFT JOIN users u ON u.id = a.created_by
    LEFT JOIN advisory_media am ON am.advisory_id = a.id
    WHERE a.status = ?${scope.sql} ORDER BY a.created_at DESC`, [status, ...scope.params]);
  res.json({ advisories: advisories.map((advisory) => ({
    ...advisory,
    media_url: publicMediaUrl(req, advisory.media_url),
  })) });
});
app.post("/api/uploads", (req, res, next) => {
  upload.fields([
    { name: "file", maxCount: 1 },
    { name: "thumbnail", maxCount: 1 },
  ])(req, res, (error) => {
    if (error) {
      if (error.code === "LIMIT_FILE_SIZE") {
        return res.status(413).json({ error: "Video is too large. Please choose a file under 100MB." });
      }
      return res.status(400).json({ error: error.message || "Unsupported file type. Please upload a valid image or video." });
    }
    next();
  });
}, async (req, res) => {
  const mediaFile = req.files?.file?.[0];
  const thumbnailFile = req.files?.thumbnail?.[0];
  if (!mediaFile) return res.status(400).json({ error: "Please select a photo or video" });
  const mediaKind = mediaFile.mimetype === "image/gif" ? "gif" : mediaFile.mimetype.startsWith("video/") ? "video" : "photo";
  if (thumbnailFile && (mediaKind !== "video" || !thumbnailFile.mimetype.startsWith("image/"))) {
    await removeTemporaryUpload(mediaFile);
    await removeTemporaryUpload(thumbnailFile);
    return res.status(400).json({ error: "A video thumbnail must be an image uploaded with a video." });
  }
  try {
    if (process.env.VERCEL && !hasCloudinaryStorage && !hasSignedCloudinaryStorage) {
      return res.status(503).json({
        error: "Media storage is not configured. Set Cloudinary storage variables before uploading media.",
      });
    }
    const cloudinaryUrl = await uploadToCloudinary(mediaFile);
    if (cloudinaryUrl) {
      const thumbnailUrl = thumbnailFile
        ? await uploadToCloudinary(thumbnailFile)
        : null;
      await removeTemporaryUpload(mediaFile);
      await removeTemporaryUpload(thumbnailFile);
      return res.status(201).json({
        url: cloudinaryUrl,
        thumbnailUrl,
        mediaKind,
        originalName: mediaFile.originalname,
        storage: "cloudinary",
      });
    }
    res.status(201).json({
      url: `${req.protocol}://${req.get("host")}/uploads/${mediaFile.filename}`,
      thumbnailUrl: thumbnailFile
        ? `${req.protocol}://${req.get("host")}/uploads/${thumbnailFile.filename}`
        : null,
      mediaKind,
      originalName: mediaFile.originalname,
      storage: "local",
    });
  } catch (uploadError) {
    await removeTemporaryUpload(mediaFile);
    await removeTemporaryUpload(thumbnailFile);
    console.error("Unable to store advisory media:", uploadError.message);
    res.status(502).json({ error: `Could not store media: ${uploadError.message}` });
  }
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
app.post("/api/uploads/convert-gif", async (req, res) => {
  const { url: bodyUrl } = req.body ?? {};
  const url = bodyUrl || req.query.url;
  if (!url) return res.status(400).json({ error: "A video URL is required" });
  let sourcePath;
  let outputPath;
  try {
    const sourceName = path.basename(new URL(String(url)).pathname);
    sourcePath = await downloadMediaForConversion(url);
    if (!fs.existsSync(sourcePath)) return res.status(404).json({ error: "Uploaded video file was not found" });
    outputPath = path.join(uploadDirectory, `${path.parse(sourceName).name}-${Date.now()}.gif`);
    await convertVideoFileToGif(sourcePath, outputPath);
    const gifFile = { path: outputPath, mimetype: "image/gif", originalname: `${sourceName}.gif` };
    const cloudinaryUrl = await uploadToCloudinary(gifFile);
    if (cloudinaryUrl) return res.status(201).json({ url: cloudinaryUrl, mediaKind: "gif", storage: "cloudinary" });
    res.status(201).json({ url: `${req.protocol}://${req.get("host")}/uploads/${path.basename(outputPath)}`, mediaKind: "gif", storage: "local" });
  } catch (conversionError) {
    console.error("Unable to convert video to GIF:", conversionError.message);
    res.status(422).json({ error: conversionError.message });
  } finally {
    if (sourcePath?.startsWith(uploadDirectory)) await fs.promises.rm(sourcePath, { force: true }).catch(() => {});
    if (outputPath) await fs.promises.rm(outputPath, { force: true }).catch(() => {});
  }
});
app.post("/api/advisories/:id/convert-gif", async (req, res) => {
  const advisoryId = Number(req.params.id);
  if (!Number.isSafeInteger(advisoryId) || advisoryId <= 0) {
    return res.status(400).json({ error: "Invalid advisory ID" });
  }
  const [advisories] = await pool.query(
    "SELECT a.id, a.barangay FROM advisories a WHERE a.id = ?",
    [advisoryId],
  );
  const advisoryScope = getAdvisoryScope(req.auth, "a");
  if (!advisories.length || !advisoryScope.allows(advisories[0])) {
    return res.status(404).json({ error: "Advisory not found" });
  }
  const [mediaRows] = await pool.query(
    "SELECT id, file_path, media_type FROM advisory_media WHERE advisory_id = ? ORDER BY id DESC LIMIT 1",
    [advisoryId],
  );
  const media = mediaRows[0];
  if (!media || media.media_type !== "video") return res.status(400).json({ error: "This advisory has no attached video to convert" });
  const sourceName = path.basename(new URL(String(media.file_path)).pathname);
  const sourcePath = await downloadMediaForConversion(media.file_path);
  if (!fs.existsSync(sourcePath)) return res.status(404).json({ error: "Attached video file was not found" });
  const outputName = `${path.parse(sourceName).name}-${Date.now()}.gif`;
  const outputPath = path.join(uploadDirectory, outputName);
  const converter = spawn(ffmpegPath, ["-y", "-i", sourcePath, "-t", "8", "-vf", "fps=12,scale=480:-1:flags=lanczos,split[s0][s1];[s0]palettegen=max_colors=128[p];[s1][p]paletteuse=dither=sierra2_4a", outputPath]);
  let errorOutput = "";
  converter.stderr.on("data", (chunk) => { errorOutput += chunk.toString(); });
  converter.on("close", async (code) => {
    try {
      if (code !== 0) return res.status(422).json({ error: "Could not convert the attached video to GIF", details: errorOutput.slice(-300) });
      const cloudinaryUrl = await uploadToCloudinary({
        path: outputPath,
        mimetype: "image/gif",
        originalname: outputName,
      });
      const gifUrl = cloudinaryUrl || `${req.protocol}://${req.get("host")}/uploads/${outputName}`;
      const updateScope = getAdvisoryScope(req.auth, "a");
      const [result] = await pool.query(
        `UPDATE advisory_media am JOIN advisories a ON a.id = am.advisory_id SET am.file_path = ?, am.media_type = 'gif' WHERE am.id = ? AND a.id = ?${updateScope.sql}`,
        [gifUrl, media.id, advisoryId, ...updateScope.params],
      );
      if (!result.affectedRows) return res.status(404).json({ error: "Advisory not found" });
      res.json({ url: gifUrl, mediaKind: "gif", storage: cloudinaryUrl ? "cloudinary" : "local" });
    } catch (error) {
      console.error("Could not update converted advisory media", error);
      if (!res.headersSent) {
        res.status(500).json({ error: "Could not update converted advisory media" });
      }
    }
  });
});
app.post("/api/advisories", async (req, res) => {
  const { type = "gen", title, message, audience = "All barangays", barangay, mediaUrl, mediaKind, mediaThumbnailUrl } = req.body ?? {};
  const publisher = req.auth;
  const adminId = publisher.id;
  const targetBarangay = publisher?.role === "barangay_staff" ? publisher.barangay : barangay ?? null;
  const targetAudience = publisher?.role === "barangay_staff" ? publisher.barangay : audience;
  if (!title?.trim() || !message?.trim()) return res.status(400).json({ error: "Title and message are required" });
  const [result] = await pool.query("INSERT INTO advisories (type, title, message, audience, barangay, created_by, published_at) VALUES (?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP)", [type, title.trim(), message.trim(), targetAudience, targetBarangay, adminId ?? null]);
  if (mediaUrl) await pool.query("INSERT INTO advisory_media (advisory_id, file_path, media_type) VALUES (?, ?, ?)", [result.insertId, mediaUrl, mediaKind || "photo"]);
  await queueAdvisoryNotifications({
    advisoryId: result.insertId,
    advisoryType: type,
    title: title.trim(),
    message: message.trim(),
    audience: targetAudience,
    imageUrl:
      String(mediaKind || "photo").toLowerCase() === "video"
        ? mediaThumbnailUrl || null
        : ["photo", "gif", "image"].includes(String(mediaKind || "photo").toLowerCase())
        ? publicMediaUrl(req, mediaUrl)
        : null,
    mediaKind: mediaKind || null,
    mediaUrl: mediaUrl || null,
  });
  const [advisories] = await pool.query("SELECT * FROM advisories WHERE id = ?", [result.insertId]);
  await writeAuditLog(req, { actorId: adminId, action: "advisory_created", resourceType: "advisory", resourceId: result.insertId, details: { title: title.trim(), audience: targetAudience } });
  res.status(201).json({ advisory: advisories[0] });
});
app.patch("/api/advisories/:id", async (req, res) => {
  const { type, title, message, audience, barangay, mediaUrl, mediaKind } = req.body ?? {};
  const editor = req.auth;
  const advisoryId = Number(req.params.id);
  if (!Number.isSafeInteger(advisoryId) || advisoryId <= 0) {
    return res.status(400).json({ error: "Invalid advisory ID" });
  }
  if (!title?.trim() || !message?.trim()) return res.status(400).json({ error: "Title and message are required" });
  const scope = getAdvisoryScope(editor, "a");
  const targetAudience = editor?.role === "barangay_staff" ? editor.barangay : audience;
  const connection = await pool.getConnection();
  let transactionStarted = false;
  try {
    await connection.beginTransaction();
    transactionStarted = true;
    const [existing] = await connection.query(
      "SELECT a.id, a.barangay FROM advisories a WHERE a.id = ? FOR UPDATE",
      [advisoryId],
    );
    if (!existing.length || !scope.allows(existing[0])) {
      await connection.rollback();
      transactionStarted = false;
      return res.status(404).json({ error: "Advisory not found" });
    }

    await connection.query(
      `UPDATE advisories SET type = COALESCE(?, type), title = ?, message = ?, audience = COALESCE(?, audience), barangay = COALESCE(?, barangay) WHERE id = ?${getAdvisoryScope(editor, "advisories").sql}`,
      [type ?? null, title.trim(), message.trim(), targetAudience ?? null, editor?.role === "barangay_staff" ? editor.barangay : barangay ?? null, advisoryId, ...scope.params],
    );
    await connection.query("DELETE FROM advisory_media WHERE advisory_id = ?", [advisoryId]);
    if (mediaUrl) {
      await connection.query(
        "INSERT INTO advisory_media (advisory_id, file_path, media_type) VALUES (?, ?, ?)",
        [advisoryId, mediaUrl, mediaKind || "photo"],
      );
    }
    const [advisories] = await connection.query("SELECT * FROM advisories WHERE id = ?", [advisoryId]);
    await connection.commit();
    transactionStarted = false;
    await writeAuditLog(req, { actorId: editor.id, action: "advisory_updated", resourceType: "advisory", resourceId: advisoryId, details: { title: title.trim() } });
    res.json({ advisory: advisories[0] });
  } catch (error) {
    if (transactionStarted) {
      try {
        await connection.rollback();
      } catch (rollbackError) {
        console.error("Could not roll back advisory update", rollbackError);
      }
    }
    throw error;
  } finally {
    connection.release();
  }
});
app.delete("/api/advisories/:id", async (req, res) => {
  const advisoryId = Number(req.params.id);
  if (!Number.isSafeInteger(advisoryId) || advisoryId <= 0) {
    return res.status(400).json({ error: "Invalid advisory ID" });
  }
  const scope = getAdvisoryScope(req.auth, "advisories");
  const connection = await pool.getConnection();
  let transactionStarted = false;
  try {
    await connection.beginTransaction();
    transactionStarted = true;
    const [advisories] = await connection.query(
      "SELECT id, barangay FROM advisories WHERE id = ? FOR UPDATE",
      [advisoryId],
    );
    if (!advisories.length || !scope.allows(advisories[0])) {
      await connection.rollback();
      transactionStarted = false;
      return res.status(404).json({ error: "Advisory not found" });
    }
    const [result] = await connection.query(
      `UPDATE advisories SET status = 'archived' WHERE id = ? AND status <> 'archived'${scope.sql}`,
      [advisoryId, ...scope.params],
    );
    if (!result.affectedRows) {
      await connection.rollback();
      transactionStarted = false;
      return res.status(404).json({ error: "Advisory not found" });
    }
    await connection.commit();
    transactionStarted = false;
  } catch (error) {
    if (transactionStarted) {
      try {
        await connection.rollback();
      } catch (rollbackError) {
        console.error("Could not roll back advisory archive", rollbackError);
      }
    }
    throw error;
  } finally {
    connection.release();
  }
  await writeAuditLog(req, { actorId: req.auth.id, action: "advisory_archived", resourceType: "advisory", resourceId: advisoryId });
  res.status(204).end();
});
app.patch("/api/users/:id/moderation", async (req, res) => {
  const { action, reason, duration, note } = req.body ?? {};
  const adminId = req.auth.id;
  const allowedActions = ["warn", "suspend", "ban", "restore"];
  if (!allowedActions.includes(action) || !reason) return res.status(400).json({ error: "A valid action and reason are required" });
  let suspensionDuration = null;
  if (action === "suspend") {
    try {
      suspensionDuration = suspensionHours(duration);
    } catch (error) {
      return res.status(400).json({ error: error.message });
    }
  }
  const connection = await pool.getConnection();
  let transactionStarted = false;
  let targetUser;
  let updatedUser;
  let moderationPushNotification;
  try {
    await connection.beginTransaction();
    transactionStarted = true;
    const [users] = await connection.query(
      "SELECT id, standing, barangay FROM users WHERE id = ? AND role = 'resident' FOR UPDATE",
      [Number(req.params.id)],
    );
    targetUser = users[0];
    if (!targetUser) {
      await connection.rollback();
      transactionStarted = false;
      return res.status(404).json({ error: "Resident account not found" });
    }
    const moderator = req.auth;
    if (!getResidentScope(moderator).allows(targetUser)) {
      await connection.rollback();
      transactionStarted = false;
      return res.status(403).json({ error: "You can only manage members in your barangay" });
    }
    if (targetUser.standing === "Banned" && action !== "restore") {
      await connection.rollback();
      transactionStarted = false;
      return res.status(409).json({ error: "Restore this banned account before applying another moderation action." });
    }
    const standing = standingAfterModeration(action, targetUser.standing);
    await connection.query(
      "INSERT INTO moderation_actions (user_id, admin_id, action, reason, duration, note) VALUES (?, ?, ?, ?, ?, ?)",
      [targetUser.id, adminId ?? null, action, reason, action === "suspend" ? duration : null, note ?? null],
    );
    if (action !== "warn") {
      const suspendedUntil =
        action === "suspend" && suspensionDuration !== null
          ? `DATE_ADD(CURRENT_TIMESTAMP, INTERVAL ${suspensionDuration} HOUR)`
          : "NULL";
      await connection.query(
        `UPDATE users SET standing = ?, suspended_until = ${suspendedUntil} WHERE id = ?`,
        [standing, targetUser.id],
      );
    }
    const notification = moderationNotification(action, duration);
    const [notificationResult] = await connection.query(
      "INSERT INTO notifications (user_id, type, title, message) VALUES (?, 'account', ?, ?)",
      [targetUser.id, notification.title, notification.message],
    );
    moderationPushNotification = {
      id: notificationResult.insertId,
      user_id: targetUser.id,
      report_id: null,
      advisory_id: null,
      type: "account",
      title: notification.title,
      message: notification.message,
    };
    const [updated] = await connection.query(
      "SELECT id, name, email, barangay, standing, suspended_until, verification FROM users WHERE id = ?",
      [targetUser.id],
    );
    updatedUser = updated[0];
    await connection.commit();
    transactionStarted = false;
  } catch (error) {
    if (transactionStarted) {
      try {
        await connection.rollback();
      } catch (rollbackError) {
        console.error("Could not roll back user moderation", rollbackError);
      }
    }
    throw error;
  } finally {
    connection.release();
  }
  await deliverNotificationPush(moderationPushNotification);
  await writeAuditLog(req, { actorId: adminId, action: `user_${action}`, resourceType: "user", resourceId: req.params.id, details: { reason, duration, note } });
  res.json({ user: updatedUser });
});
app.patch("/api/users/:id/verification", async (req, res) => {
  const decision = String(req.body?.decision || "").toLowerCase();
  if (!["approve", "reject"].includes(decision)) {
    return res.status(400).json({ error: "Choose approve or reject for this verification." });
  }

  const [[targetUser]] = await pool.query(
    "SELECT id, name, barangay, verification FROM users WHERE id = ? AND role = 'resident'",
    [Number(req.params.id)],
  );
  if (!targetUser) return res.status(404).json({ error: "Resident account not found" });
  if (!getResidentScope(req.auth).allows(targetUser)) {
    return res.status(403).json({ error: "You can only review residents in your barangay." });
  }

  const [documents] = await pool.query(
    "SELECT id, document_type FROM verification_documents WHERE user_id = ?",
    [targetUser.id],
  );
  const hasId = documents.some((document) => document.document_type !== "selfie");
  const hasSelfie = documents.some((document) => document.document_type === "selfie");
  if (!hasId || !hasSelfie) {
    return res.status(400).json({
      error: "Both the government ID and live selfie must be submitted before review.",
    });
  }

  const status = decision === "approve" ? "approved" : "rejected";
  const verification = decision === "approve" ? "Verified" : "ID mismatch";
  await pool.query(
    "UPDATE verification_documents SET status = ?, reviewed_by = ?, reviewed_at = CURRENT_TIMESTAMP WHERE user_id = ?",
    [status, req.auth.id, targetUser.id],
  );
  await pool.query("UPDATE users SET verification = ? WHERE id = ?", [
    verification,
    targetUser.id,
  ]);
  if (decision === "approve") {
    const welcomeNotification = verificationApprovalNotification(
      targetUser.verification,
    );
    if (welcomeNotification) {
      await queueNotification({
        userId: targetUser.id,
        ...welcomeNotification,
      });
    }
  }
  await writeAuditLog(req, {
    actorId: req.auth.id,
    action: `user_verification_${decision}d`,
    resourceType: "user",
    resourceId: targetUser.id,
    details: { verification },
  });
  res.json({ ok: true, verification });
});
app.get("/api/reports", async (req, res) => {
  const userId = Number(req.query.userId);
  const [reports] = await pool.query(`SELECT r.*, u.name AS reporter FROM reports r LEFT JOIN users u ON u.id = r.reporter_id ${userId ? "WHERE r.reporter_id = ?" : ""} ORDER BY r.created_at DESC`, userId ? [userId] : []);
  res.json({ reports });
});
app.post("/api/reports", async (req, res) => {
  const { title, description, category, location, latitude, longitude, severity = "Medium", reporterId } = req.body ?? {};
  const normalizedCategory = normalizeReportCategory(category);
  if (!title || !description || !normalizedCategory) {
    return res.status(400).json({ error: `Title, description, and a valid category are required (${REPORT_CATEGORIES.join(", ")})` });
  }

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
  const [result] = await pool.query("INSERT INTO reports (public_id, title, description, category, location, latitude, longitude, severity, reporter_id, due_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, DATE_ADD(CURRENT_TIMESTAMP, INTERVAL 3 DAY))", [id, title, description, normalizedCategory, resolvedLocation, parsedLat ?? null, parsedLng ?? null, severity, reporterId ?? null]);
  await pool.query("INSERT INTO report_events (report_id, status, note) VALUES (?, 'Reported', ?)", [result.insertId, "Report submitted by resident"]);
  const [reports] = await pool.query("SELECT * FROM reports WHERE id = ?", [result.insertId]);
  const report = reports[0];
  await evaluateIssueAutomation(report);
  await writeAuditLog(req, { actorId: req.auth?.id ?? reporterId, action: "report_created", resourceType: "report", resourceId: id, details: { title, category: normalizedCategory, location: resolvedLocation } });
  res.status(201).json({ report });
});
app.patch("/api/issues/:id", async (req, res) => {
  const { status, assignedTeam, resolutionNote, severity, progressPercentage, progressNote, beforeMediaUrl, afterMediaUrl } = req.body ?? {};
  if (severity != null && !REPORT_SEVERITIES.includes(severity)) {
    return res.status(400).json({ error: "Choose a valid report severity." });
  }
  const parsedProgress = Number(progressPercentage);
  const progress = Number.isFinite(parsedProgress)
    ? Math.min(100, Math.max(0, Math.round(parsedProgress)))
    : null;
  const [rows] = await pool.query(
    `SELECT r.*, u.barangay AS reporter_barangay
      FROM reports r
      LEFT JOIN users u ON u.id = r.reporter_id
      WHERE r.public_id = ? OR r.id = ?`,
    [req.params.id, Number(req.params.id)],
  );
  const report = rows[0];
  if (!report) return res.status(404).json({ error: "Report not found" });
  const editor = req.auth;
  if (!getReportScope(editor).allows(report)) {
    return res.status(403).json({ error: "You can only manage issues in your barangay" });
  }
  const nextStatus = status ?? report.status;
  const progressError = progressUpdateError({
    currentStatus: report.status,
    nextStatus,
    currentProgress: Number(report.progress_percentage) || 0,
    nextProgress: progress,
    progressNote,
  });
  if (progressError) return res.status(400).json({ error: progressError });
  const progressNoteText = typeof progressNote === "string" ? progressNote.trim() : "";
  if (beforeMediaUrl && (typeof beforeMediaUrl !== "string" || (!isDurableMediaUrl(beforeMediaUrl) && !beforeMediaUrl.startsWith("/uploads/")))) {
    return res.status(400).json({ error: "Invalid replacement report photo URL" });
  }
  if (afterMediaUrl && (typeof afterMediaUrl !== "string" || (!isDurableMediaUrl(afterMediaUrl) && !afterMediaUrl.startsWith("/uploads/")))) {
    return res.status(400).json({ error: "Invalid resolution photo URL" });
  }
  await pool.query("UPDATE reports SET status = COALESCE(?, status), assigned_team = COALESCE(?, assigned_team), resolution_note = COALESCE(?, resolution_note), severity = COALESCE(?, severity), progress_percentage = COALESCE(?, progress_percentage) WHERE id = ?", [status ?? null, assignedTeam ?? null, resolutionNote ?? null, severity ?? null, progress, report.id]);
  if (beforeMediaUrl) {
    const [mediaRows] = await pool.query("SELECT id FROM media WHERE report_id = ? AND media_type IN ('photo', 'gif') ORDER BY id ASC LIMIT 1", [report.id]);
    if (mediaRows.length) {
      await pool.query("UPDATE media SET file_path = ?, media_type = 'photo' WHERE id = ?", [beforeMediaUrl, mediaRows[0].id]);
    } else {
      await pool.query("INSERT INTO media (report_id, file_path, media_type) VALUES (?, ?, 'photo')", [report.id, beforeMediaUrl]);
    }
  }
  if (afterMediaUrl) {
    const [resolutionMediaRows] = await pool.query(
      "SELECT id FROM media WHERE report_id = ? AND media_type = 'resolution_photo' ORDER BY id DESC LIMIT 1",
      [report.id],
    );
    if (resolutionMediaRows.length) {
      await pool.query(
        "UPDATE media SET file_path = ? WHERE id = ?",
        [afterMediaUrl, resolutionMediaRows[0].id],
      );
    } else {
      await pool.query(
        "INSERT INTO media (report_id, file_path, media_type) VALUES (?, ?, 'resolution_photo')",
        [report.id, afterMediaUrl],
      );
    }
  }
  const statusChanged = Boolean(status && status !== report.status);
  const progressChanged = progress !== null && progress !== Number(report.progress_percentage);
  if (statusChanged) {
    const eventNote = status === "In progress"
      ? progressNoteText || null
      : resolutionNote ?? null;
    await pool.query(
      "INSERT INTO report_events (report_id, status, note) VALUES (?, ?, ?)",
      [report.id, status, eventNote],
    );
  } else if (nextStatus === "In progress" && (progressChanged || progressNoteText)) {
    await pool.query(
      "INSERT INTO report_events (report_id, status, note) VALUES (?, 'In progress', ?)",
      [report.id, progressNoteText || null],
    );
  }
  const assignmentChanged = Boolean(assignedTeam && assignedTeam !== report.assigned_team);
  if (report.reporter_id && (statusChanged || assignmentChanged)) {
    const updateMessage = statusChanged
      ? `Your report "${report.title}" is now ${status}.`
      : `A response team has been assigned to your report "${report.title}".`;
    await queueNotification({
      userId: report.reporter_id,
      reportId: report.id,
      type: "report",
      title: "Report status update",
      message: updateMessage,
    });
  }
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
