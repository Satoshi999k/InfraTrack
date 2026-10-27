import test from "node:test";
import assert from "node:assert/strict";
import {
  residentAccountCreatedEmail,
  residentAccountVerifiedEmail,
  sendResidentAccountCreatedEmail,
  sendResidentAccountVerifiedEmail,
} from "./accountEmailNotifications.js";

const resident = {
  id: 14,
  name: "Mati Resident",
  email: "resident@example.com",
};

test("account-created email explains verification without including credentials", () => {
  const email = residentAccountCreatedEmail(resident, {
    appUrl: "https://infratrack.example.com",
  });

  assert.equal(email.recipient, resident.email);
  assert.equal(email.subject, "Welcome to InfraTrack");
  assert.match(email.body, /account has been created/i);
  assert.match(email.body, /complete identity verification/i);
  assert.doesNotMatch(email.body, /password|secret/i);
  assert.equal(email.template.actionUrl, "https://infratrack.example.com");
});

test("account-verified email confirms resident reporting access", () => {
  const email = residentAccountVerifiedEmail(resident);

  assert.equal(email.recipient, resident.email);
  assert.match(email.subject, /account is verified/i);
  assert.match(email.body, /now submit community infrastructure reports/i);
  assert.equal(email.template.eyebrow, "ACCOUNT VERIFIED");
});

test("email delivery failures are reported without interrupting account actions", async () => {
  const errors = [];
  const result = await sendResidentAccountCreatedEmail(resident, {
    sendEmail: async () => {
      throw new Error("delivery unavailable");
    },
    logger: { error: (...args) => errors.push(args) },
  });

  assert.deepEqual(result, {
    sent: false,
    configured: true,
    reason: "delivery_failed",
  });
  assert.equal(errors.length, 1);
  assert.match(errors[0][0], /account 14/);
});

test("verified-account email returns the delivery result for admin feedback", async () => {
  let notification;
  const result = await sendResidentAccountVerifiedEmail(resident, {
    sendEmail: async (email) => {
      notification = email;
      return { sent: true, configured: true, provider: "emailjs" };
    },
    logger: { error: assert.fail, info() {} },
  });

  assert.equal(notification.recipient, resident.email);
  assert.equal(notification.subject, "Your InfraTrack account is verified");
  assert.deepEqual(result, {
    sent: true,
    configured: true,
    provider: "emailjs",
  });
});
