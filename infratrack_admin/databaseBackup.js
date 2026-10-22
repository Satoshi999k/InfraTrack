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
