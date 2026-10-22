import test from "node:test";
import assert from "node:assert/strict";
import path from "node:path";
import {
  createPortableDatabaseBackup,
  describeMysqlDumpNotFound,
  resolveMysqlDumpPath,
} from "./databaseBackup.js";

test("database backup uses the mysqldump bundled with XAMPP on Windows", () => {
  const appDirectory = path.resolve("D:/xampp2/htdocs/InfraTrack/infratrack_admin");
  const expectedPath = "D:\\xampp2\\mysql\\bin\\mysqldump.exe";

  assert.equal(
    resolveMysqlDumpPath(appDirectory, {
      configuredPath: "",
      platform: "win32",
      fileExists: (candidate) => candidate === expectedPath,
    }),
    expectedPath,
  );
});

test("database backup honors an explicitly configured mysqldump path", () => {
  assert.equal(
    resolveMysqlDumpPath("D:/app", {
      configuredPath: "D:/tools/mysql/mysqldump.exe",
      platform: "win32",
      fileExists: () => false,
    }),
    "D:/tools/mysql/mysqldump.exe",
  );
});

test("database backup falls back to PATH when no bundled utility exists", () => {
  assert.equal(
    resolveMysqlDumpPath("D:/app", {
      configuredPath: "",
      platform: "win32",
      fileExists: () => false,
    }),
    "mysqldump",
  );
});

test("database backup uses MariaDB's dump utility on Linux when available", () => {
  assert.equal(
    resolveMysqlDumpPath("/opt/render/project/src/infratrack_admin", {
      configuredPath: "",
      platform: "linux",
      fileExists: (candidate) => candidate === "/usr/bin/mariadb-dump",
    }),
    "/usr/bin/mariadb-dump",
  );
});

test("missing mysqldump errors explain how to configure the executable", () => {
  assert.match(
    describeMysqlDumpNotFound("mysqldump"),
    /Install the MySQL or MariaDB client.*MYSQLDUMP_PATH/,
  );
});

test("portable backup includes table definitions and safely encoded database rows", async () => {
  const queries = [];
  let released = false;
  let committed = false;
  const connection = {
    async query(sql) {
      queries.push(sql);
      if (sql.startsWith("SHOW FULL TABLES")) {
        return [[
          { Tables_in_infratrack: "users", Table_type: "BASE TABLE" },
          { Tables_in_infratrack: "summary", Table_type: "VIEW" },
        ]];
      }
      if (sql.startsWith("SHOW CREATE TABLE")) {
        return [[{
          Table: "users",
          "Create Table": "CREATE TABLE `users` (`id` int NOT NULL, `name` text)",
        }]];
      }
      if (sql.startsWith("SELECT * FROM")) {
        return [[
          { id: 7, name: "O'Reilly\\Road\n" },
          { id: 8, name: null },
        ]];
      }
      if (sql.startsWith("SHOW CREATE VIEW")) {
        return [[{
          View: "summary",
          "Create View": "CREATE VIEW `summary` AS SELECT `id` FROM `users`",
        }]];
      }
      return [[]];
    },
    async commit() { committed = true; },
    async rollback() {},
    release() { released = true; },
  };
  const pool = { async getConnection() { return connection; } };

  const backup = await createPortableDatabaseBackup(pool, "infratrack");

  assert.match(backup, /CREATE TABLE `users`/);
  assert.match(
    backup,
    /VALUES \(7, CONVERT\(X'4f275265696c6c795c526f61640a' USING utf8mb4\)\)/,
  );
  assert.match(backup, /VALUES \(8, NULL\)/);
  assert.match(backup, /DROP VIEW IF EXISTS `infratrack`\.`summary`/);
  assert.match(backup, /CREATE VIEW `summary` AS SELECT `id` FROM `users`/);
  assert.match(backup, /SET FOREIGN_KEY_CHECKS=1;/);
  assert.equal(committed, true);
  assert.equal(released, true);
  assert.equal(queries[0], "SET TRANSACTION ISOLATION LEVEL REPEATABLE READ");
});

test("portable backup releases its connection and reports table-definition errors", async () => {
  let rolledBack = false;
  let released = false;
  const connection = {
    async query(sql) {
      if (sql.startsWith("SHOW FULL TABLES")) {
        return [[{ Tables_in_infratrack: "users", Table_type: "BASE TABLE" }]];
      }
      if (sql.startsWith("SHOW CREATE TABLE")) return [[{ Table: "users" }]];
      return [[]];
    },
    async commit() {},
    async rollback() { rolledBack = true; },
    release() { released = true; },
  };

  await assert.rejects(
    createPortableDatabaseBackup(
      { async getConnection() { return connection; } },
      "infratrack",
    ),
    /Could not read the definition for table "users"/,
  );
  assert.equal(rolledBack, true);
  assert.equal(released, true);
});
