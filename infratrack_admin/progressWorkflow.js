export function progressUpdateError({
  currentStatus,
  nextStatus,
  currentProgress,
  nextProgress,
  progressNote,
}) {
  if (progressNote != null && typeof progressNote !== "string") {
    return "Enter a progress update for the resident.";
  }
  if (typeof progressNote === "string" && progressNote.length > 1000) {
    return "Progress updates must be 1,000 characters or fewer.";
  }

  const progressChanged =
    Number.isFinite(nextProgress) && nextProgress !== currentProgress;
  if (
    nextStatus === "In progress" &&
    (currentStatus !== "In progress" || progressChanged) &&
    !(typeof progressNote === "string" && progressNote.trim())
  ) {
    return "Add a progress update for the resident before saving.";
  }

  return null;
}

export function attachReportEventsToReports(reports, events) {
  const reportIds = new Set(reports.map((report) => String(report.id)));
  const updatesByReportId = new Map();
  const statusHistoryByReportId = new Map();

  for (const event of events) {
    const reportId = String(event.report_id);
    if (!reportIds.has(reportId)) continue;

    if (["Reported", "Verified by inspector", "In progress"].includes(event.status)) {
      const history = statusHistoryByReportId.get(reportId) ?? [];
      history.push({ status: event.status, created_at: event.created_at });
      statusHistoryByReportId.set(reportId, history);
    }

    if (event.status === "In progress" && typeof event.note === "string" && event.note.trim()) {
      const updates = updatesByReportId.get(reportId) ?? [];
      updates.push({ note: event.note, created_at: event.created_at });
      updatesByReportId.set(reportId, updates);
    }
  }

  return reports.map((report) => ({
    ...report,
    progress_updates: updatesByReportId.get(String(report.id)) ?? [],
    status_history: statusHistoryByReportId.get(String(report.id)) ?? [],
  }));
}
