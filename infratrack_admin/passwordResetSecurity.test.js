import test from "node:test";
import assert from "node:assert/strict";
import {
  createPasswordResetCode,
  hashPasswordResetCode,
  matchesPasswordResetCode,
  normalizeResetEmail,
} from "./passwordResetSecurity.js";

test("creates a six-digit password reset code including leading zeroes", () => {
  for (let index = 0; index < 100; index += 1) {
    assert.match(createPasswordResetCode(), /^\d{6}$/);
  }
});

test("normalizes reset email addresses consistently", () => {
  assert.equal(normalizeResetEmail("  Resident@Example.com "), "resident@example.com");
});

test("stores a keyed code digest and compares it without accepting another email or code", () => {
  const email = "resident@example.com";
  const code = "004281";
  const secret = "test-reset-secret";
  const digest = hashPasswordResetCode(email, code, secret);

  assert.match(digest, /^[\da-f]{64}$/);
  assert.equal(matchesPasswordResetCode(email, code, digest, secret), true);
  assert.equal(matchesPasswordResetCode(email, "004282", digest, secret), false);
  assert.equal(matchesPasswordResetCode("other@example.com", code, digest, secret), false);
  assert.equal(matchesPasswordResetCode(email, code, digest, "rotated-secret"), false);
  assert.equal(matchesPasswordResetCode(email, "4281", digest, secret), false);
});

test("requires a configured server secret to hash codes", () => {
  assert.throws(
    () => hashPasswordResetCode("resident@example.com", "123456", ""),
    /secret is not configured/,
  );
});
