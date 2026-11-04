const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const source = fs.readFileSync(path.join(__dirname, "InboxPage.jsx"), "utf8");

test("inbox exposes the professional support workspace structure", () => {
  assert.match(source, /inbox-thread-list/);
  assert.match(source, /inbox-conversation/);
});

test("inbox exposes citizen context and support actions", () => {
  for (const label of ["Category", "Urgency", "Barangay", "Subject", "Message", "Assign", "Mark resolved", "Close", "Reopen"]) {
    assert.ok(source.includes(label), `missing Inbox UI text: ${label}`);
  }
});

test("inbox uses Lucide controls instead of Material icon names", () => {
  assert.doesNotMatch(source, /person_add|task_alt|attach_file|arrow_back|restart_alt/);
  assert.match(source, /lucide-react/);
});
