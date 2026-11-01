import "dotenv/config";
import mysql from "mysql2/promise";
import { hashPassword } from "./passwordHash.js";

const databaseName =
  (process.env.DB_NAME || "infratrack").replace(/[^a-zA-Z0-9_]/g, "") ||
  "infratrack";
const databaseConfig = {
  host: process.env.DB_HOST || "127.0.0.1",
  port: Number(process.env.DB_PORT || 3306),
  user: process.env.DB_USER || "root",
  password: process.env.DB_PASSWORD || "",
  ssl: /^true$/i.test(process.env.DB_SSL || "false")
    ? { minVersion: "TLSv1.2" }
    : undefined,
};

async function provisionAdmin() {
  const name = String(process.env.INITIAL_ADMIN_NAME || "").trim();
  const email = String(process.env.INITIAL_ADMIN_EMAIL || "")
    .trim()
    .toLowerCase();
  const password = process.env.INITIAL_ADMIN_PASSWORD || "";
  if (!name || name.length > 120) {
    throw new Error(
      "Set INITIAL_ADMIN_NAME to a name of at most 120 characters.",
    );
  }
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email) || email.length > 255) {
    throw new Error("Set INITIAL_ADMIN_EMAIL to a valid email address.");
  }
  if (password.length < 12) {
    throw new Error(
      "INITIAL_ADMIN_PASSWORD must contain at least 12 characters.",
    );
  }
  const connection = await mysql.createConnection(databaseConfig);
  try {
    await connection.query(
      `CREATE DATABASE IF NOT EXISTS \`${databaseName}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci`,
    );
    await connection.query(`USE \`${databaseName}\``);
    const [[adminCount]] = await connection.query(
      "SELECT COUNT(*) AS count FROM users WHERE role IN ('lgu', 'admin')",
    );
    if (Number(adminCount.count) > 0) {
      throw new Error(
        "An administrator already exists. This command only provisions the first LGU administrator.",
      );
    }

    await connection.query(
      `INSERT INTO users
       (name, email, mobile, barangay, password_hash, role, verification)
       VALUES (?, ?, '', 'Mati City', ?, 'lgu', 'Verified')`,
      [name, email, hashPassword(password)],
    );
    console.log(`Provisioned the first LGU administrator: ${email}`);
  } finally {
    await connection.end();
  }
}

provisionAdmin().catch((error) => {
  console.error("Administrator provisioning failed:", error.message);
  process.exitCode = 1;
});
