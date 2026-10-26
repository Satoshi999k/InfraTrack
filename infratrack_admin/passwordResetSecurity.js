import crypto from "node:crypto";

export function normalizeResetEmail(email) {
  return String(email ?? "").trim().toLowerCase();
}

export function createPasswordResetCode() {
  return String(crypto.randomInt(0, 1_000_000)).padStart(6, "0");
}

export function hashPasswordResetCode(email, code, secret) {
  if (!secret) throw new Error("Password reset code secret is not configured.");
  return crypto
    .createHmac("sha256", secret)
    .update(`${normalizeResetEmail(email)}\0${code}`)
    .digest("hex");
}

export function matchesPasswordResetCode(email, code, expectedHash, secret) {
  if (!/^\d{6}$/.test(String(code ?? "")) || !/^[\da-f]{64}$/i.test(String(expectedHash ?? ""))) {
    return false;
  }

  const actual = Buffer.from(hashPasswordResetCode(email, String(code), secret), "hex");
  const expected = Buffer.from(String(expectedHash), "hex");
  return crypto.timingSafeEqual(actual, expected);
}
