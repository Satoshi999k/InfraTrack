import test from "node:test";
import assert from "node:assert/strict";
import {
  formatAnalyticsTrendLabel,
  getAnalyticsCategoryRows,
} from "./analyticsDisplay.js";

test("analytics category rows account for reports in unrecognized categories", () => {
  assert.deepEqual(
    getAnalyticsCategoryRows(
      [
        { name: "Roads", count: "12" },
        { name: "Drainage", count: 3 },
      ],
      28,
    ),
    [
      { name: "Roads", count: 12 },
      { name: "Drainage", count: 3 },
      { name: "Other categories", count: 13 },
    ],
  );
});

test("analytics category rows do not create an empty remainder", () => {
  assert.deepEqual(getAnalyticsCategoryRows([{ name: "Roads", count: 2 }], 2), [
    { name: "Roads", count: 2 },
  ]);
  assert.deepEqual(getAnalyticsCategoryRows([], 0), []);
});

test("analytics trend labels explain date and time buckets", () => {
  assert.equal(formatAnalyticsTrendLabel("2026-10-22", "month"), "Oct 22");
  assert.equal(formatAnalyticsTrendLabel("2026-10", "year"), "Oct 26");
  assert.equal(
    formatAnalyticsTrendLabel("2026-10-22 18:00", "day"),
    "Oct 22, 6 PM",
  );
  assert.equal(formatAnalyticsTrendLabel("Unknown", "week"), "Unknown");
});
