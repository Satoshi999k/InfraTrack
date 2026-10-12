import test from "node:test";
import assert from "node:assert/strict";
import { analyzeReportThemes } from "./thematicAnalysis.js";

test("assigns each report to one primary theme based on category and report text", () => {
  const themes = analyzeReportThemes([
    { category: "Roads", title: "Large potholes", description: "Unsafe street access" },
    { category: "Other", title: "Canal overflowing", description: "Flooding after rain" },
    { category: "Other", title: "Broken streetlight", description: "Dark road at night" },
  ]);

  assert.deepEqual(themes.map(({ name, count }) => [name, count]), [
    ["Drainage & flooding", 1],
    ["Lighting & electricity", 1],
    ["Roads & transportation", 1],
  ]);
  assert.equal(themes.reduce((total, theme) => total + theme.count, 0), 3);
});

test("uses the report category as a fallback signal and groups unmatched reports", () => {
  const themes = analyzeReportThemes([
    { category: "Water", title: "No service", description: "Residents report an interruption" },
    { category: "Uncategorized", title: "Community concern", description: "Needs investigation" },
  ]);

  assert.deepEqual(themes.map(({ name, count }) => [name, count]), [
    ["Other infrastructure concerns", 1],
    ["Water supply", 1],
  ]);
});

test("returns no themes when there are no reports", () => {
  assert.deepEqual(analyzeReportThemes([]), []);
});
