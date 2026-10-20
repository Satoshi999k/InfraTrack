import test from "node:test";
import assert from "node:assert/strict";

import {
  moderationNotification,
  standingAfterModeration,
  suspensionHours,
} from "./moderationPolicy.js";

test("warnings notify the resident without changing account standing", () => {
  assert.equal(standingAfterModeration("warn", "Active"), "Active");
  assert.equal(standingAfterModeration("warn", "Suspended"), "Suspended");
  assert.match(moderationNotification("warn").message, /account remains active/i);
});

test("suspensions restrict reporting for an explicitly selected period", () => {
  assert.equal(standingAfterModeration("suspend", "Active"), "Suspended");
  assert.equal(suspensionHours("24 hours"), 24);
  assert.equal(suspensionHours("3 days"), 72);
  assert.equal(suspensionHours("7 days"), 168);
  assert.equal(suspensionHours("14 days"), 336);
  assert.equal(suspensionHours("30 days"), 720);
  assert.equal(suspensionHours("Permanent"), null);
  assert.match(moderationNotification("suspend", "3 days").message, /3 days/);
  assert.equal(
    moderationNotification("suspend", "Permanent").title,
    "Reporting access suspended",
  );
  assert.throws(() => suspensionHours("forever"), /valid suspension duration/);
});

test("bans block access until an administrator restores the account", () => {
  assert.equal(standingAfterModeration("ban"), "Banned");
  assert.equal(standingAfterModeration("restore", "Banned"), "Active");
  assert.match(moderationNotification("ban").message, /cannot sign in/i);
  assert.match(moderationNotification("restore").message, /active again/i);
});
