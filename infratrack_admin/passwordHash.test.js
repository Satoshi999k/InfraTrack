import test from "node:test";
import assert from "node:assert/strict";
import { hashPassword } from "./passwordHash.js";

test("password hashing stores a salted scrypt digest", () => {
  const firstHash = hashPassword("long-test-password");
  const secondHash = hashPassword("long-test-password");

  assert.match(firstHash, /^scrypt\$[a-f0-9]{32}\$[a-f0-9]{128}$/);
  assert.notEqual(firstHash, secondHash);
});
