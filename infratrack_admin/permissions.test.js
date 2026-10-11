import test from "node:test";
import assert from "node:assert/strict";

import { canManageSystemSettings } from "./permissions.js";

test("only LGU administrators can manage city-wide system settings", () => {
  assert.equal(canManageSystemSettings("lgu"), true);
  assert.equal(canManageSystemSettings("admin"), true);
  assert.equal(canManageSystemSettings("barangay_staff"), false);
  assert.equal(canManageSystemSettings("resident"), false);
});
