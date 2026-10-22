import { existsSync } from "node:fs";
import path from "node:path";

export function resolveMysqlDumpPath(
  appDirectory,
  {
    configuredPath = process.env.MYSQLDUMP_PATH,
    platform = process.platform,
    fileExists = existsSync,
  } = {},
) {
  if (configuredPath?.trim()) return configuredPath.trim();

  if (platform === "win32") {
    const xamppDumpPath = path.resolve(
      appDirectory,
      "..",
      "..",
      "..",
      "mysql",
      "bin",
      "mysqldump.exe",
    );
    if (fileExists(xamppDumpPath)) return xamppDumpPath;
  }

  const availableCommands =
    platform === "win32"
      ? ["mysqldump"]
      : ["/usr/bin/mysqldump", "/usr/bin/mariadb-dump", "mysqldump", "mariadb-dump"];
  return (
    availableCommands.find((command) => command.includes("/") && fileExists(command)) ||
    availableCommands.find((command) => !command.includes("/")) ||
    "mysqldump"
  );
}

export function describeMysqlDumpNotFound(dumpPath) {
  return `MySQL dump utility was not found at "${dumpPath}". Install the MySQL or MariaDB client, or set MYSQLDUMP_PATH to the full path of mysqldump or mariadb-dump.`;
}

function quoteIdentifier(value) {
  return `\`${String(value).replaceAll("`", "``")}\``;
}

function sqlLiteral(value) {
  if (value === null || value === undefined) return "NULL";
  if (typeof value === "boolean") return value ? "1" : "0";
  if (typeof value === "number") {
    if (!Number.isFinite(value)) {
      throw new Error("Database backup encountered a non-finite number.");
    }
    return String(value);
  }
  if (typeof value === "bigint") return String(value);
  if (Buffer.isBuffer(value)) return `X'${value.toString("hex")}'`;
  if (value instanceof Date) {
    if (Number.isNaN(value.getTime())) {
      throw new Error("Database backup encountered an invalid date.");
    }
    const pad = (part, length = 2) => String(part).padStart(length, "0");
    const date = `${pad(value.getFullYear(), 4)}-${pad(value.getMonth() + 1)}-${pad(value.getDate())}`;
    const time = `${pad(value.getHours())}:${pad(value.getMinutes())}:${pad(value.getSeconds())}`;
    const milliseconds = value.getMilliseconds();
    return `'${date} ${time}${milliseconds ? `.${pad(milliseconds, 3)}` : ""}'`;
  }
  const text =
    typeof value === "object" ? JSON.stringify(value) : String(value);
  return `CONVERT(X'${Buffer.from(text, "utf8").toString("hex")}' USING utf8mb4)`;
}

export async function createPortableDatabaseBackup(pool, databaseName) {
  const connection = await pool.getConnection();
  const database = quoteIdentifier(databaseName);
  const statements = [
    "-- InfraTrack database backup",
    "SET NAMES utf8mb4;",
    "SET FOREIGN_KEY_CHECKS=0;",
  ];

  try {
    await connection.query("SET TRANSACTION ISOLATION LEVEL REPEATABLE READ");
    await connection.query("START TRANSACTION WITH CONSISTENT SNAPSHOT");

    const [tableRows] = await connection.query(
      `SHOW FULL TABLES FROM ${database}`,
    );
    const tables = tableRows
      .filter((row) => row.Table_type === "BASE TABLE")
      .map((row) => row[Object.keys(row).find((key) => key !== "Table_type")])
      .filter(Boolean);
    const views = tableRows
      .filter((row) => row.Table_type === "VIEW")
      .map((row) => row[Object.keys(row).find((key) => key !== "Table_type")])
      .filter(Boolean);

    for (const viewName of views) {
      statements.push(
        `DROP VIEW IF EXISTS ${database}.${quoteIdentifier(viewName)};`,
      );
    }

    for (const tableName of tables) {
      const qualifiedName = `${database}.${quoteIdentifier(tableName)}`;
      const [definitionRows] = await connection.query(
        `SHOW CREATE TABLE ${qualifiedName}`,
      );
      const definitionKey = Object.keys(definitionRows[0] || {}).find((key) =>
        key.startsWith("Create"),
      );
      if (!definitionKey || !definitionRows[0][definitionKey]) {
        throw new Error(`Could not read the definition for table "${tableName}".`);
      }
      statements.push(
        `\nDROP TABLE IF EXISTS ${qualifiedName};`,
        `${definitionRows[0][definitionKey]};`,
      );
    }

    for (const tableName of tables) {
      const qualifiedName = `${database}.${quoteIdentifier(tableName)}`;
      const [rows] = await connection.query(
        `SELECT * FROM ${qualifiedName}`,
      );
      for (const row of rows) {
        const columns = Object.keys(row);
        const values = columns.map((column) => sqlLiteral(row[column]));
        statements.push(
          `INSERT INTO ${qualifiedName} (${columns.map(quoteIdentifier).join(", ")}) VALUES (${values.join(", ")});`,
        );
      }
    }

    for (const viewName of views) {
      const qualifiedName = `${database}.${quoteIdentifier(viewName)}`;
      const [definitionRows] = await connection.query(
        `SHOW CREATE VIEW ${qualifiedName}`,
      );
      const definitionKey = Object.keys(definitionRows[0] || {}).find((key) =>
        key.startsWith("Create"),
      );
      if (!definitionKey || !definitionRows[0][definitionKey]) {
        throw new Error(`Could not read the definition for view "${viewName}".`);
      }
      statements.push(`${definitionRows[0][definitionKey]};`);
    }

    statements.push("\nSET FOREIGN_KEY_CHECKS=1;");
    await connection.commit();
    return `${statements.join("\n")}\n`;
  } catch (error) {
    await connection.rollback();
    throw error;
  } finally {
    connection.release();
  }
}
