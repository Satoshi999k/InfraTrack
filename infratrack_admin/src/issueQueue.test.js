import test from "node:test";
import assert from "node:assert/strict";
import {
  countIssueQueueStatuses,
  filterIssueQueue,
  getAvailableIssueBarangays,
  paginateIssueQueue,
} from "./issueQueue.js";

const now = Date.parse("2026-10-22T10:00:00Z");
const issues = [
  {
    id: 1,
    status: "Reported",
    category: "Road",
    location: "Brgy. Central",
    created_at: "2026-10-20T10:00:00Z",
  },
  {
    id: 2,
    status: "In progress",
    category: "Drainage",
    location: "Mati City",
    reporter_barangay: "Dawan",
    created_at: "2026-10-18T10:00:00Z",
  },
  {
    id: 3,
    status: "Resolved",
    category: "Roads",
    location: "Brgy. Central",
    created_at: "2026-09-01T10:00:00Z",
  },
  {
    id: 4,
    status: "Verified by inspector",
    category: "Streetlights",
    location: "Brgy. Dawan",
    created_at: "invalid-date",
  },
];

test("queue filters combine category, barangay, and date constraints", () => {
  const filtered = filterIssueQueue(
    issues,
    {
      category: "Roads",
      barangay: "central",
      date: "30",
    },
    now,
  );

  assert.deepEqual(
    filtered.map((issue) => issue.id),
    [1],
  );
});

test("queue status counts use the currently selected non-status filters", () => {
  const selectedIssues = filterIssueQueue(issues, { barangay: "dawan" }, now);

  assert.deepEqual(countIssueQueueStatuses(selectedIssues), {
    all: 2,
    pending: 0,
    "In progress": 1,
    Resolved: 0,
  });
});

test("queue barangay choices are unique and based on available reports", () => {
  assert.deepEqual(getAvailableIssueBarangays(issues), [
    { value: "central", label: "Brgy. Central" },
    { value: "dawan", label: "Brgy. Dawan" },
  ]);
});

test("queue pagination returns accurate ranges and clamps stale pages", () => {
  const reports = Array.from({ length: 23 }, (_, index) => ({ id: index + 1 }));

  assert.deepEqual(paginateIssueQueue(reports, 2), {
    currentPage: 2,
    totalPages: 3,
    startIndex: 10,
    endIndex: 20,
    issues: reports.slice(10, 20),
  });
  assert.equal(paginateIssueQueue(reports, 9).currentPage, 3);
  assert.equal(paginateIssueQueue([], 2).totalPages, 1);
});
