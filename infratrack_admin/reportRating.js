export const REPORT_RATING_COMMENT_MAX_LENGTH = 500;

export function canOwnReportRating(user, report) {
  return (
    user?.role === "resident" &&
    report?.reporter_id != null &&
    Number(user.id) === Number(report.reporter_id)
  );
}

export function canRateReport(user, report) {
  return canOwnReportRating(user, report) && report.status === "Resolved";
}

export function validateReportRating(rating, comment) {
  if (!Number.isInteger(rating) || rating < 1 || rating > 5) {
    return "Choose a rating from 1 to 5 stars.";
  }
  if (comment != null && typeof comment !== "string") {
    return "Feedback must be text.";
  }
  if (comment?.trim().length > REPORT_RATING_COMMENT_MAX_LENGTH) {
    return `Feedback must be ${REPORT_RATING_COMMENT_MAX_LENGTH} characters or fewer.`;
  }
  return null;
}
