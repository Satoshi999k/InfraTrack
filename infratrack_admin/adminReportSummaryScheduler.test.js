import test from "node:test";
import assert from "node:assert/strict";
import {
  formatAdminReportSummary,
  getDueReportPeriods,
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
