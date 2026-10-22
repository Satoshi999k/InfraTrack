import test from "node:test";
import assert from "node:assert/strict";

import {
  canReplyToReport,
  isReportDiscussionOpen,
  REPORT_COMMENT_MAX_LENGTH,
  validateReportComment,
} from "./reportDiscussion.js";

test("report discussion replies require non-empty text within the message limit", () => {
  assert.equal(validateReportComment("  "), "Enter a reply before sending.");
  assert.equal(validateReportComment(null), "Enter a reply before sending.");
  assert.equal(validateReportComment(" A useful update "), null);
  assert.equal(
    validateReportComment("x".repeat(REPORT_COMMENT_MAX_LENGTH)),
    null,
  );
  assert.equal(
    validateReportComment("x".repeat(REPORT_COMMENT_MAX_LENGTH + 1)),
    `Replies must be ${REPORT_COMMENT_MAX_LENGTH} characters or fewer.`,
  );
});

test("only the report owner or authorized staff can post discussion replies", () => {
  const report = { reporter_id: 12 };

  assert.equal(canReplyToReport({ id: "12", role: "resident" }, report), true);
  assert.equal(canReplyToReport({ id: 13, role: "resident" }, report), false);
  assert.equal(canReplyToReport({ id: 1, role: "lgu" }, null), false);
  assert.equal(canReplyToReport({ id: 1, role: "barangay_staff" }, report), true);
  assert.equal(canReplyToReport({ id: 1, role: "lgu" }, report), true);
  assert.equal(canReplyToReport({ id: 1, role: "unknown" }, report), false);
});

test("discussion replies close when a report is resolved, rejected, or archived", () => {
  assert.equal(isReportDiscussionOpen("Reported"), true);
  assert.equal(isReportDiscussionOpen("In progress"), true);
  assert.equal(isReportDiscussionOpen("Resolved"), false);
  assert.equal(isReportDiscussionOpen("Rejected"), false);
  assert.equal(isReportDiscussionOpen("Archived"), false);
});
