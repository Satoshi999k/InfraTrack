import test from "node:test";
import assert from "node:assert/strict";

import { getAdvisoryAudience, validateAdvisoryDraft } from "./advisoryForm.js";

test("advisory validation explains which required field is missing", () => {
  assert.equal(validateAdvisoryDraft("  ", "Message"), "Enter an advisory title.");
  assert.equal(validateAdvisoryDraft("Title", "  "), "Enter an advisory message.");
  assert.equal(validateAdvisoryDraft(" Title ", " Message "), null);
});

test("barangay staff audience is always their assigned barangay", () => {
  assert.equal(
    getAdvisoryAudience(
      { role: "barangay_staff", barangay: "Brgy. Central" },
      "All barangays",
    ),
    "Brgy. Central",
  );
});

test("LGU audience follows the selected recipient scope", () => {
  assert.equal(getAdvisoryAudience({ role: "lgu" }, "Brgy. Dawan"), "Brgy. Dawan");
  assert.equal(
    getAdvisoryAudience({ role: "lgu" }, "All barangays"),
    "All barangays",
  );
});
