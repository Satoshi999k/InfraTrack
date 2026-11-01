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

test("reports with coordinates are not grouped by the reporter's home barangay", () => {
  const issue = {
    location: "Mati City",
    latitude: 6.9450796,
    longitude: 126.2323952,
    reporter_barangay: "Barangay Central",
  };

  assert.equal(issueMatchesBarangay(issue, "Brgy. Central"), false);
  assert.equal(issueMatchesBarangay(issue, "Brgy. Matiao"), false);
});
