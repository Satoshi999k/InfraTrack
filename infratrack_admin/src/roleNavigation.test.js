import test from "node:test";
import assert from "node:assert/strict";

import { canAccessAdminPage, getNavigationGroups } from "./roleNavigation.js";

test("barangay staff see scoped operations and barangay work, not LGU user management", () => {
  const groups = getNavigationGroups("barangay_staff");

  assert.deepEqual(
    groups.flatMap((group) => group.items.map(([id]) => id)),
    [
      "overview",
      "queue",
      "map",
      "analytics",
      "users",
      "announce",
      "published",
      "logs",
    ],
  );
  assert.equal(groups[1].items[0][1], "Residents");
  assert.equal(groups[1].label, "Barangay");
});

test("barangay staff cannot access LGU-only pages but retain account settings", () => {
  assert.equal(canAccessAdminPage("barangay_staff", "users"), true);
  assert.equal(canAccessAdminPage("barangay_staff", "announce"), true);
  assert.equal(canAccessAdminPage("barangay_staff", "settings"), true);
  assert.equal(canAccessAdminPage("barangay_staff", "backup"), false);
  assert.equal(canAccessAdminPage("resident", "overview"), false);
});

test("LGU administrators keep administration navigation", () => {
  const groups = getNavigationGroups("lgu");

  assert.equal(groups[1].label, "Administration");
  assert.equal(groups[1].items[0][1], "User Management");
  assert.equal(canAccessAdminPage("lgu", "users"), true);
});
