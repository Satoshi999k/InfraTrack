import test from "node:test";
import assert from "node:assert/strict";
import { getDashboardSummary } from "./dashboardSummary.js";

test("dashboard summary counts reports by active and resolved status", () => {
  const summary = getDashboardSummary([
    { id: 1, status: "Reported", severity: "High" },
    { id: 2, status: "Verified by inspector", severity: "Critical", assigned_team: "Roads Team" },
    { id: 3, status: "In progress", severity: "Medium", assignedTeam: "Water Team" },
    { id: 4, status: "In progress", severity: "Low", assigned_team: "Unassigned" },
    { id: 5, status: "Resolved", severity: "Critical" },
    { id: 6, status: "Rejected", severity: "High" },
    { id: 7, status: "Archived", severity: "Critical" },
  ]);

  assert.equal(summary.totalCount, 7);
  assert.equal(summary.activeCount, 4);
  assert.equal(summary.completedCount, 1);
  assert.deepEqual(summary.inProgressIssues.map((issue) => issue.id), [3, 4]);
});
