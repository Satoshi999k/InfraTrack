export function validateAdvisoryDraft(title, message) {
  if (!title.trim()) return "Enter an advisory title.";
  if (!message.trim()) return "Enter an advisory message.";
  return null;
}

export function getAdvisoryAudience(user, selectedAudience) {
  if (user?.role === "barangay_staff") {
    return user.barangay || "your assigned barangay";
  }
  return selectedAudience;
}
