import test from "node:test";
import assert from "node:assert/strict";
import {
  aggregateReportCategories,
  normalizeReportCategory,
  REPORT_CATEGORIES,
} from "./reportCategories.js";

test("exposes only the infrastructure categories in scope", () => {
  assert.deepEqual(REPORT_CATEGORIES, [
    "Roads",
    "Public Buildings",
    "Streetlights",
    "Electric Poles",
    "Drainage",
  ]);
});

test("normalizes existing road and lighting names to the current categories", () => {
  assert.equal(normalizeReportCategory("Road"), "Roads");
  assert.equal(normalizeReportCategory("LIGHTING"), "Streetlights");
});

test("rejects categories outside the infrastructure scope", () => {
  assert.equal(normalizeReportCategory("Water"), null);
  assert.equal(normalizeReportCategory("Debris"), null);
});

test("category analytics combine legacy aliases and exclude out-of-scope data", () => {
  assert.deepEqual(
    aggregateReportCategories([
      { name: "Lighting", count: 2 },
      { name: "Streetlights", count: 3 },
      { name: "Water", count: 4 },
      { name: "Electric Poles", count: 1 },
    ]),
    [
      { name: "Streetlights", count: 5 },
      { name: "Electric Poles", count: 1 },
    ],
  );
});
