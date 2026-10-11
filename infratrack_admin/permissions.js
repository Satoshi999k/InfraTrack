export function canManageSystemSettings(role) {
  return role === "lgu" || role === "admin";
}
