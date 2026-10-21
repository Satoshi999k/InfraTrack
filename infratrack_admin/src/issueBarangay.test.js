import assert from "node:assert/strict";
import test from "node:test";
import { issueMatchesBarangay } from "./issueBarangay.js";

test("generic Mati City reports use their reporter's registered barangay", () => {
  const issue = {
    location: "Mati City",
    reporter_barangay: "Barangay Central",
  };

  assert.equal(issueMatchesBarangay(issue, "Brgy. Central"), true);
  assert.equal(issueMatchesBarangay(issue, "Brgy. Dawan"), false);
});

test("an explicit report location takes priority over reporter barangay", () => {
  const issue = {
    location: "Brgy. Dawan",
    reporter_barangay: "Barangay Central",
  };

  assert.equal(issueMatchesBarangay(issue, "Barangay Dawan"), true);
  assert.equal(issueMatchesBarangay(issue, "Barangay Central"), false);
});
