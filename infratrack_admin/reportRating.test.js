import assert from "node:assert/strict";
import test from "node:test";

import {
  canOwnReportRating,
  canRateReport,
  REPORT_RATING_COMMENT_MAX_LENGTH,
  validateReportRating,
} from "./reportRating.js";

test("only the report owner can submit a resident rating", () => {
  const report = { reporter_id: 42, status: "Resolved" };

  assert.equal(
    canOwnReportRating({ id: "42", role: "resident" }, report),
    true,
  );
  assert.equal(canOwnReportRating({ id: 43, role: "resident" }, report), false);
  assert.equal(canOwnReportRating({ id: 42, role: "lgu" }, report), false);
  assert.equal(canOwnReportRating({ id: 42, role: "resident" }, null), false);
});

test("a report can be rated only after it is resolved", () => {
  const owner = { id: 42, role: "resident" };

  assert.equal(
    canRateReport(owner, { reporter_id: 42, status: "Resolved" }),
    true,
  );
  assert.equal(
    canRateReport(owner, { reporter_id: 42, status: "In progress" }),
    false,
  );
  assert.equal(
    canRateReport(owner, { reporter_id: 42, status: "Rejected" }),
    false,
  );
});

test("ratings must be whole stars from one to five with bounded optional feedback", () => {
  assert.equal(validateReportRating(1), null);
  assert.equal(validateReportRating(5, "Repair was completed well."), null);
  assert.equal(validateReportRating(0), "Choose a rating from 1 to 5 stars.");
  assert.equal(validateReportRating(6), "Choose a rating from 1 to 5 stars.");
  assert.equal(validateReportRating(3.5), "Choose a rating from 1 to 5 stars.");
  assert.equal(validateReportRating("5"), "Choose a rating from 1 to 5 stars.");
  assert.equal(
    validateReportRating(4, "x".repeat(REPORT_RATING_COMMENT_MAX_LENGTH)),
    null,
  );
  assert.equal(
    validateReportRating(4, "x".repeat(REPORT_RATING_COMMENT_MAX_LENGTH + 1)),
    `Feedback must be ${REPORT_RATING_COMMENT_MAX_LENGTH} characters or fewer.`,
  );
});
