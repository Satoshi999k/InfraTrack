const CLOSED_STATUSES = new Set(["resolved", "rejected", "archived"]);

function normalizedStatus(issue) {
  return String(issue.status || "").trim().toLowerCase();
}

function isActiveReport(issue) {
  return !CLOSED_STATUSES.has(normalizedStatus(issue));
}

export function getDashboardSummary(issues) {
  const activeIssues = issues.filter(isActiveReport);
  const inProgressIssues = activeIssues.filter((issue) => normalizedStatus(issue) === "in progress");

  return {
    totalCount: issues.length,
    activeCount: activeIssues.length,
    completedCount: issues.filter((issue) => normalizedStatus(issue) === "resolved").length,
    inProgressIssues,
  };
}
