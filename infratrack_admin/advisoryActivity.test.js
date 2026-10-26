import test from "node:test";
import assert from "node:assert/strict";

import {
  groupAdvisoryComments,
  normalizeAdvisoryEngagement,
} from "./advisoryActivity.js";

test("advisory activity normalizes optional display values and preserves parent IDs", () => {
  const engagement = normalizeAdvisoryEngagement({
    advisory: { id: 12, title: "Road closure" },
    comments: [
      { id: 1, parent_comment_id: null, author_name: null },
      { id: 2, parent_comment_id: 1, author_name: "Resident", body: "Reply" },
    ],
    reactions: [{ user_id: 4, user_name: null }],
  });

  assert.equal(engagement.comments[0].author_name, "Former user");
  assert.equal(engagement.comments[1].parent_comment_id, 1);
  assert.equal(engagement.comments[1].body, "Reply");
  assert.equal(engagement.reactions[0].user_name, "Former user");
});

test("advisory activity rejects malformed payloads with explicit errors", () => {
  assert.throws(
    () =>
      normalizeAdvisoryEngagement({
        advisory: { id: 12 },
        comments: [null],
        reactions: [],
      }),
    /invalid advisory comments/,
  );
});

test("advisory replies remain grouped beneath their root comment", () => {
  const comments = [
    { id: 1, parent_comment_id: null, body: "Root" },
    { id: 2, parent_comment_id: 1, body: "Reply" },
    { id: 3, parent_comment_id: 1, body: "Reply to reply" },
    { id: 4, parent_comment_id: null, body: "Another root" },
  ];

  const { topLevelComments, repliesByParent } = groupAdvisoryComments(comments);

  assert.deepEqual(
    topLevelComments.map((comment) => comment.id),
    [1, 4],
  );
  assert.deepEqual(
    repliesByParent.get(1).map((comment) => comment.id),
    [2, 3],
  );
});
