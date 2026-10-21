import test from "node:test";
import assert from "node:assert/strict";

import {
  attachReportEventsToReports,
  progressUpdateError,
} from "./progressWorkflow.js";

const current = {
  currentStatus: "Reported",
  nextStatus: "In progress",
  currentProgress: 0,
  nextProgress: 25,
};

test("requires a resident-facing note when a report enters progress", () => {
  assert.equal(
    progressUpdateError({ ...current, progressNote: "  " }),
    "Add a progress update for the resident before saving.",
  );
});

test("accepts a note when a report enters progress", () => {
  assert.equal(
    progressUpdateError({
      ...current,
      progressNote: "The repair crew has inspected the damaged section.",
    }),
    null,
  );
});

test("requires a new note when progress percentage changes", () => {
  assert.equal(
    progressUpdateError({
      currentStatus: "In progress",
      nextStatus: "In progress",
      currentProgress: 25,
      nextProgress: 50,
      progressNote: "",
    }),
    "Add a progress update for the resident before saving.",
  );
});

test("requires a note when the percentage first changes from zero", () => {
  assert.equal(
    progressUpdateError({
      currentStatus: "In progress",
      nextStatus: "In progress",
      currentProgress: 0,
      nextProgress: 50,
      progressNote: "",
    }),
    "Add a progress update for the resident before saving.",
  );
});

test("allows unchanged progress to save without adding another update", () => {
  assert.equal(
    progressUpdateError({
      currentStatus: "In progress",
      nextStatus: "In progress",
      currentProgress: 50,
      nextProgress: 50,
      progressNote: "",
    }),
    null,
  );
});

test("rejects oversized progress notes", () => {
  assert.equal(
    progressUpdateError({
      ...current,
      progressNote: "x".repeat(1001),
    }),
    "Progress updates must be 1,000 characters or fewer.",
  );
});

test("attaches report events only to the supplied resident report records", () => {
  const reports = [{ id: 12, title: "Resident-owned report" }];
  const result = attachReportEventsToReports(reports, [
    {
      report_id: 12,
      status: "In progress",
      note: "Crew is repairing the water line.",
      created_at: "2026-10-21T05:00:00.000Z",
    },
    {
      report_id: 99,
      status: "In progress",
      note: "This belongs to another resident.",
      created_at: "2026-10-21T05:01:00.000Z",
    },
    {
      report_id: 12,
      status: "Verified by inspector",
      note: null,
      created_at: "2026-10-20T05:30:00.000Z",
    },
    {
      report_id: 12,
      status: "Reported",
      note: "Initial submission.",
      created_at: "2026-10-20T05:00:00.000Z",
    },
  ]);

  assert.deepEqual(result, [
    {
      id: 12,
      title: "Resident-owned report",
      progress_updates: [
        {
          note: "Crew is repairing the water line.",
          created_at: "2026-10-21T05:00:00.000Z",
        },
      ],
      status_history: [
        {
          status: "In progress",
          created_at: "2026-10-21T05:00:00.000Z",
        },
        {
          status: "Verified by inspector",
          created_at: "2026-10-20T05:30:00.000Z",
        },
        {
          status: "Reported",
          created_at: "2026-10-20T05:00:00.000Z",
        },
      ],
    },
  ]);
});
