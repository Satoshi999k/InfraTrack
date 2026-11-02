import test from "node:test";
import assert from "node:assert/strict";
import {
  formatAdminReportSummary,
  getNextMonthlyEmailRetryAt,
  getDueReportPeriods,
  startAdminReportSummaryScheduler,
} from "./adminReportSummaryScheduler.js";

test("weekly summary is due Monday morning in Mati City time for the previous full week", () => {
  assert.deepEqual(getDueReportPeriods(new Date("2026-02-02T00:00:00.000Z")), [
    { type: "weekly", start: "2026-01-26", end: "2026-02-02" },
  ]);
});

test("monthly summary is due on the last day after 8 a.m. in Mati City time", () => {
  assert.deepEqual(getDueReportPeriods(new Date("2026-03-31T00:00:00.000Z")), [
    { type: "monthly", start: "2026-03-01", end: "2026-04-01" },
  ]);
  assert.deepEqual(
    getDueReportPeriods(new Date("2026-03-30T23:59:00.000Z")),
    [],
  );
  assert.deepEqual(
    getDueReportPeriods(new Date("2026-04-01T01:00:00.000Z")),
    [],
  );
});

test("monthly summary handles February's last day, including leap years", () => {
  assert.deepEqual(getDueReportPeriods(new Date("2026-02-28T00:00:00.000Z")), [
    { type: "monthly", start: "2026-02-01", end: "2026-03-01" },
  ]);
  assert.deepEqual(getDueReportPeriods(new Date("2028-02-29T00:00:00.000Z")), [
    { type: "monthly", start: "2028-02-01", end: "2028-03-01" },
  ]);
});

test("summary email includes counts, top categories, and the reporting period", () => {
  const summary = formatAdminReportSummary(
    { type: "weekly", start: "2026-01-26", end: "2026-02-02" },
    { total_count: 9, resolved_count: 4, open_count: 5, urgent_count: 2 },
    [
      { category: "Roads", report_count: 6 },
      { category: "Drainage", report_count: 3 },
    ],
  );

  assert.match(summary.subject, /Weekly Report Summary/);
  assert.match(summary.body, /Reports submitted: 9/);
  assert.match(summary.body, /Resolved: 4/);
  assert.match(summary.body, /Open or in progress: 5/);
  assert.match(summary.body, /Critical or high severity: 2/);
  assert.match(summary.body, /Roads: 6/);
  assert.match(summary.body, /Jan 26, 2026/);
});

test("failed report email cooldown starts at the next Manila calendar month", () => {
  assert.equal(
    getNextMonthlyEmailRetryAt(new Date("2026-11-02T02:10:00.000Z")),
    "2026-11-30 16:00:00",
  );
});

test("EmailJS quota failure stops the recipient batch and pauses retries for the month", async () => {
  let quotaRetryAfter = null;
  let sendCount = 0;
  let insertCount = 0;
  let failureUpdate;
  let resolveFailureUpdated;
  const failureUpdated = new Promise((resolve) => {
    resolveFailureUpdated = resolve;
  });
  const connection = {
    async query(sql, params = []) {
      if (sql.includes("GET_LOCK")) return [[{ acquired: 1 }], []];
      if (sql.includes("failure_class = 'provider_quota'")) {
        return quotaRetryAfter ? [[{ blocked: 1 }], []] : [[], []];
      }
      if (sql.includes("INSERT IGNORE INTO admin_report_email_runs")) {
        insertCount++;
        assert.match(sql, /status = 'failed'/);
        assert.match(sql, /retry_after/);
        return [{ affectedRows: 2 }, []];
      }
      if (sql.includes("SELECT COUNT(*) AS total_count")) {
        return [[{ total_count: 0, resolved_count: 0, open_count: 0, urgent_count: 0 }], []];
      }
      if (sql.includes("SELECT category, COUNT(*)")) return [[], []];
      if (sql.includes("SELECT runs.recipient_id")) {
        return [[
          { recipient_id: 5, email: "first@example.com" },
          { recipient_id: 6, email: "second@example.com" },
        ], []];
      }
      if (sql.includes("SET status = 'failed', failure_class = ?")) {
        failureUpdate = { sql, params };
        if (params[0] === "provider_quota") quotaRetryAfter = params[1];
        resolveFailureUpdated();
        return [{ affectedRows: 1 }, []];
      }
      if (sql.includes("RELEASE_LOCK")) return [[{ released: 1 }], []];
      throw new Error(`Unexpected SQL in test: ${sql}`);
    },
    release() {},
  };
  const pool = { getConnection: async () => connection };
  const timer = startAdminReportSummaryScheduler({
    pool,
    intervalMs: 5,
    now: () => new Date("2026-11-02T02:10:00.000Z"),
    sendEmail: async () => {
      sendCount++;
      const error = new Error(
        "EmailJS email request failed with status 426: Monthly request quota exceeded",
      );
      error.status = 426;
      throw error;
    },
    logger: { error() {} },
  });

  try {
    await failureUpdated;
    await new Promise((resolve) => setTimeout(resolve, 30));
  } finally {
    clearInterval(timer);
  }

  assert.equal(sendCount, 1);
  assert.equal(insertCount, 1);
  assert.equal(failureUpdate.params[0], "provider_quota");
  assert.equal(failureUpdate.params[1], "2026-11-30 16:00:00");
});
