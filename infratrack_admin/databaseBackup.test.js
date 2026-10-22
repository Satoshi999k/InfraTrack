import test from "node:test";
import assert from "node:assert/strict";
import path from "node:path";
import {
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
