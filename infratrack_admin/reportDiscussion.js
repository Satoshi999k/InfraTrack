export const REPORT_COMMENT_MAX_LENGTH = 1000;

const STAFF_ROLES = new Set(["admin", "lgu", "barangay_staff"]);
const CLOSED_REPORT_STATUSES = new Set(["Resolved", "Rejected", "Archived"]);

export function validateReportComment(body) {
  if (typeof body !== "string") {
    return "Enter a reply before sending.";
  }

  const message = body.trim();
  if (!message) return "Enter a reply before sending.";
  if (message.length > REPORT_COMMENT_MAX_LENGTH) {
    return `Replies must be ${REPORT_COMMENT_MAX_LENGTH} characters or fewer.`;
  }

  return null;
}

export function canReplyToReport(user, report) {
  if (!report) return false;
  if (user?.role === "resident") {
    return Number(user.id) === Number(report?.reporter_id);
  }

  return STAFF_ROLES.has(user?.role);
}

export function isReportDiscussionOpen(status) {
  return !CLOSED_REPORT_STATUSES.has(status);
}
