import test from "node:test";
import assert from "node:assert/strict";
import {
  findDuplicateAccount,
  normalizeMobileNumber,
} from "./accountValidation.js";

test("normalizes valid 11-digit mobile numbers", () => {
  assert.equal(normalizeMobileNumber("0912 345 6789"), "09123456789");
  assert.equal(normalizeMobileNumber("(0912)345-6789"), "09123456789");
});

test("rejects mobile numbers that do not contain exactly 11 digits", () => {
  assert.equal(normalizeMobileNumber("0912345678"), null);
  assert.equal(normalizeMobileNumber("091234567890"), null);
  assert.equal(normalizeMobileNumber("09123456abc"), null);
  assert.equal(normalizeMobileNumber(""), null);
});

test("checks name, email, and normalized mobile for an existing account", async () => {
  let executedQuery;
  const connection = {
    async query(query, params) {
      executedQuery = { query, params };
      return [[{ id: 8 }]];
    },
  };

  const duplicate = await findDuplicateAccount(connection, {
    name: "  Maria Santos ",
    email: " maria@example.com ",
    mobile: "09123456789",
    excludeId: 5,
  });

  assert.deepEqual(duplicate, { id: 8 });
  assert.match(executedQuery.query, /LOWER\(TRIM\(name\)\)/);
  assert.match(executedQuery.query, /LOWER\(TRIM\(email\)\)/);
  assert.match(executedQuery.query, /REGEXP_REPLACE/);
  assert.deepEqual(executedQuery.params, [
    "Maria Santos",
    "maria@example.com",
    "09123456789",
    5,
  ]);
});

test("returns null when no account identity matches", async () => {
  const connection = {
    async query() {
      return [[]];
    },
  };

  assert.equal(
    await findDuplicateAccount(connection, {
      name: "Maria Santos",
      email: "maria@example.com",
      mobile: "09123456789",
    }),
    null,
  );
});
