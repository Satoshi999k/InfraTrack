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

  const executable = platform === "win32" ? "mysqldump.exe" : "mysqldump";
  const xamppPath = path.resolve(
    appDirectory,
    "..",
    "..",
    "..",
    "mysql",
    "bin",
    executable,
  );
  if (fileExists(xamppPath)) return xamppPath;

  return "mysqldump";
}

export function describeMysqlDumpNotFound(dumpPath) {
  return `mysqldump was not found at "${dumpPath}". Set MYSQLDUMP_PATH in infratrack_admin/.env to the full path of mysqldump.exe.`;
}
