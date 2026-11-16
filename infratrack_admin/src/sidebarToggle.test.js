import test from "node:test";
import assert from "node:assert/strict";
import { getSidebarToggle } from "./sidebarToggle.js";

test("expanded sidebar toggle offers the collapse action", () => {
  assert.deepEqual(getSidebarToggle(false), {
    nextCollapsed: true,
    label: "Collapse sidebar",
  });
});

test("collapsed sidebar toggle offers the expand action", () => {
  assert.deepEqual(getSidebarToggle(true), {
    nextCollapsed: false,
    label: "Expand sidebar",
  });
});
