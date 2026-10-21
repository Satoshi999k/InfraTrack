import assert from "node:assert/strict";
import test from "node:test";
import { filterResidents, paginateResidents } from "./residentSearch.js";

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

test("resident pagination returns a bounded page and range", () => {
  const accounts = Array.from({ length: 23 }, (_, index) => ({
    name: `Resident ${index + 1}`,
  }));

  assert.deepEqual(paginateResidents(accounts, 2), {
    items: accounts.slice(10, 20),
    page: 2,
    pageCount: 3,
    start: 11,
    end: 20,
    total: 23,
  });
  assert.deepEqual(paginateResidents(accounts, 3).items, accounts.slice(20));
});

test("resident pagination clamps pages and handles empty results", () => {
  assert.equal(paginateResidents(residents, 99).page, 1);
  assert.deepEqual(paginateResidents([], 1), {
    items: [],
    page: 1,
    pageCount: 1,
    start: 0,
    end: 0,
    total: 0,
  });
});
