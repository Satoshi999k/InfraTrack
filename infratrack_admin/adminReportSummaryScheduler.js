import { sendEmailNotification } from "./emailNotifications.js";

const TIME_ZONE = "Asia/Manila";
const SCHEDULED_HOUR = 8;
const LOCK_NAME = "infratrack_admin_report_summary";

function getManilaDateParts(date) {
  const parts = new Intl.DateTimeFormat("en-US", {
    timeZone: TIME_ZONE,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    weekday: "long",
    hour: "2-digit",
    hourCycle: "h23",
  }).formatToParts(date);
  return Object.fromEntries(parts.map(({ type, value }) => [type, value]));
}

function shiftDate(dateString, days) {
  const date = new Date(`${dateString}T00:00:00.000Z`);
  date.setUTCDate(date.getUTCDate() + days);
  return date.toISOString().slice(0, 10);
}

export function getDueReportPeriods(date = new Date()) {
  const parts = getManilaDateParts(date);
  if (Number(parts.hour) < SCHEDULED_HOUR) return [];

  const today = `${parts.year}-${parts.month}-${parts.day}`;
  const tomorrow = shiftDate(today, 1);
  const periods = [];
  if (parts.weekday === "Monday") {
    periods.push({
      type: "weekly",
      start: shiftDate(today, -7),
      end: today,
    });
  }
  if (tomorrow.slice(0, 7) !== today.slice(0, 7)) {
    periods.push({
      type: "monthly",
      start: `${parts.year}-${parts.month}-01`,
      end: tomorrow,
    });
  }
  return periods;
}

function formatPeriod(period) {
  const formatDate = (value) =>
    new Intl.DateTimeFormat("en", {
      dateStyle: "medium",
      timeZone: "UTC",
    }).format(new Date(`${value}T00:00:00.000Z`));
  return `${formatDate(period.start)} – ${formatDate(shiftDate(period.end, -1))}`;
}

export function formatAdminReportSummary(period, totals, categories) {
  const title = period.type === "weekly" ? "Weekly" : "Monthly";
  const range = formatPeriod(period);
  const topCategories = categories.length
    ? categories
        .map(
          ({ category, report_count }) =>
            `• ${category}: ${Number(report_count)}`,
        )
        .join("\n")
    : "No reports were submitted during this period.";

  return {
    subject: `InfraTrack ${title} Report Summary — ${range}`,
    body: [
      `Here is the ${title.toLowerCase()} infrastructure report summary for ${range}.`,
      `Reports submitted: ${Number(totals.total_count || 0)}`,
      `Resolved: ${Number(totals.resolved_count || 0)}`,
      `Open or in progress: ${Number(totals.open_count || 0)}`,
      `Critical or high severity: ${Number(totals.urgent_count || 0)}`,
      `Top report categories:\n${topCategories}`,
      "This summary covers reports by submission date and is intended for InfraTrack administrators.",
    ].join("\n\n"),
    template: {
      eyebrow: `${title} REPORT SUMMARY`,
      note: `Reporting period: ${range}. This message was generated automatically by InfraTrack.`,
    },
  };
}

async function sendPeriodSummary(connection, period, sendEmail, logger) {
  await connection.query(
    `INSERT IGNORE INTO admin_report_email_runs (period_type, period_start, recipient_id)
     SELECT ?, ?, id
     FROM users
     WHERE role IN ('admin', 'lgu')
       AND COALESCE(standing, 'Active') = 'Active'
       AND TRIM(COALESCE(email, '')) <> ''`,
    [period.type, period.start],
  );

  const [[totals]] = await connection.query(
    `SELECT COUNT(*) AS total_count,
       COALESCE(SUM(status = 'Resolved'), 0) AS resolved_count,
       COALESCE(SUM(status NOT IN ('Resolved', 'Rejected', 'Archived')), 0) AS open_count,
       COALESCE(SUM(LOWER(severity) IN ('critical', 'high')), 0) AS urgent_count
     FROM reports
     WHERE created_at >= ? AND created_at < ?`,
    [period.start, period.end],
  );
  const [categories] = await connection.query(
    `SELECT category, COUNT(*) AS report_count
     FROM reports
     WHERE created_at >= ? AND created_at < ?
     GROUP BY category
     ORDER BY report_count DESC, category ASC
     LIMIT 5`,
    [period.start, period.end],
  );
  const [recipients] = await connection.query(
    `SELECT runs.recipient_id, users.email
     FROM admin_report_email_runs runs
     JOIN users ON users.id = runs.recipient_id
     WHERE runs.period_type = ? AND runs.period_start = ? AND runs.status = 'pending'`,
    [period.type, period.start],
  );
  const summary = formatAdminReportSummary(period, totals, categories);

  for (const recipient of recipients) {
    try {
      const result = await sendEmail({
        recipient: recipient.email,
        ...summary,
      });
      if (!result.sent) {
        logger.error(
          `Admin ${period.type} report email was not sent to account ${recipient.recipient_id} (${result.reason || "unknown delivery error"}).`,
        );
        continue;
      }
      await connection.query(
        `UPDATE admin_report_email_runs
         SET status = 'sent', sent_at = CURRENT_TIMESTAMP
         WHERE period_type = ? AND period_start = ? AND recipient_id = ? AND status = 'pending'`,
        [period.type, period.start, recipient.recipient_id],
      );
    } catch (error) {
      logger.error(
        `Admin ${period.type} report email failed for account ${recipient.recipient_id}:`,
        error.message,
      );
    }
  }
}

export function startAdminReportSummaryScheduler({
  pool,
  sendEmail = sendEmailNotification,
  logger = console,
  intervalMs = 60_000,
  now = () => new Date(),
}) {
  let running = false;
  const checkAndSend = async () => {
    if (running) return;
    const periods = getDueReportPeriods(now());
    if (periods.length === 0) return;
    running = true;
    let connection;
    let lockAcquired = false;
    try {
      connection = await pool.getConnection();
      const [[lock]] = await connection.query(
        "SELECT GET_LOCK(?, 0) AS acquired",
        [LOCK_NAME],
      );
      lockAcquired = Number(lock.acquired) === 1;
      if (!lockAcquired) return;
      for (const period of periods) {
        await sendPeriodSummary(connection, period, sendEmail, logger);
      }
    } catch (error) {
      logger.error("Scheduled admin report summary failed:", error.message);
    } finally {
      if (connection) {
        if (lockAcquired) {
          try {
            await connection.query("SELECT RELEASE_LOCK(?)", [LOCK_NAME]);
          } catch (error) {
            logger.error(
              "Could not release admin report summary lock:",
              error.message,
            );
          }
        }
        connection.release();
      }
      running = false;
    }
  };

  void checkAndSend();
  return setInterval(() => void checkAndSend(), intervalMs);
}
