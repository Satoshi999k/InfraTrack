import assert from "node:assert/strict";
import test from "node:test";
import { filterResidents } from "./residentSearch.js";

const residents = [
  {
    name: "Miguelito Ok",
    email: "mig6@gmail.com",
    barangay: "Barangay Central",
  },
  {
    name: "Whats Up",
    email: "marlo3@gmail.com",
    barangay: "Barangay Central",
  },
  {
    name: "John Maverick",
    email: "john@example.com",
    barangay: "Barangay Dawan",
  },
];

test("resident search matches name, email, and barangay without case sensitivity", () => {
  assert.deepEqual(filterResidents(residents, "MIGUELITO"), [residents[0]]);
  assert.deepEqual(filterResidents(residents, "MARLO3@GMAIL"), [residents[1]]);
  assert.deepEqual(
    filterResidents(residents, "barangay central"),
    [residents[0], residents[1]],
  );
});

test("blank resident search returns all residents", () => {
  assert.deepEqual(filterResidents(residents, "  "), residents);
});
