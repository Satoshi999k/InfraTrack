import test from "node:test";
import assert from "node:assert/strict";

import { formatAdvisoryMention } from "./advisoryReply.js";

test("advisory replies prefill only a clean mention of the commenter", () => {
  assert.equal(formatAdvisoryMention("Kenneth Marathon"), "@Kenneth Marathon ");
  assert.equal(formatAdvisoryMention("  Maria   Santos  "), "@Maria Santos ");
});

test("advisory reply mention is empty when the author name is unavailable", () => {
  assert.equal(formatAdvisoryMention("  "), "");
  assert.equal(formatAdvisoryMention(null), "");
});
