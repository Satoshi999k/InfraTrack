export function serializeAdminAuthUser(user, avatarUrl = user.avatar_url) {
  return {
    id: user.id,
    name: user.name,
    email: user.email,
    barangay: user.barangay,
    avatar_url: avatarUrl,
    role: user.role,
    standing: user.standing,
    suspended_until: user.suspended_until,
  };
}
