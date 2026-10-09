import test from "node:test";
import assert from "node:assert/strict";
import { renderBrandedEmail, sendEmailNotification } from "./emailNotifications.js";

test("sends a transactional email through Brevo without exposing credentials in the payload", async () => {
  let request;
  const result = await sendEmailNotification(
    {
      recipient: "staff@example.com",
      subject: "Password changed",
      body: "Your password was changed.",
      template: {
        eyebrow: "SECURITY ALERT",
        note: "This email does not include your password.",
        actionUrl: "https://infratrack.example.com",
        actionLabel: "Sign in to InfraTrack",
      },
    },
    {
      env: {
        BREVO_API_KEY: "test-api-key",
        BREVO_SENDER_EMAIL: "no-reply@example.com",
        BREVO_SENDER_NAME: "InfraTrack",
        BREVO_LOGO_URL: "https://example.com/infratrack-logo.png",
      },
      fetchImpl: async (url, options) => {
        request = { url, options };
        return { ok: true, status: 201 };
      },
    },
  );

  assert.equal(result.sent, true);
  assert.equal(result.provider, "brevo");
  assert.equal(request.url, "https://api.brevo.com/v3/smtp/email");
  assert.equal(request.options.headers["api-key"], "test-api-key");
  const payload = JSON.parse(request.options.body);
  assert.deepEqual(payload, {
    sender: { name: "InfraTrack", email: "no-reply@example.com" },
    to: [{ email: "staff@example.com" }],
    subject: "Password changed",
    textContent: "Your password was changed.",
    htmlContent: renderBrandedEmail({
      subject: "Password changed",
      body: "Your password was changed.",
      senderName: "InfraTrack",
      logoUrl: "https://example.com/infratrack-logo.png",
      eyebrow: "SECURITY ALERT",
      note: "This email does not include your password.",
      actionUrl: "https://infratrack.example.com",
      actionLabel: "Sign in to InfraTrack",
    }),
  });
  assert.match(payload.htmlContent, /<!doctype html>/i);
  assert.match(payload.htmlContent, /Your password was changed\./);
  assert.match(payload.htmlContent, /https:\/\/example\.com\/infratrack-logo\.png/);
  assert.match(payload.htmlContent, /#0e3a4c/);
  assert.match(payload.htmlContent, /#1b8a83/);
  assert.match(payload.htmlContent, /#c1592b/);
  assert.match(payload.htmlContent, /#f3efe6/);
  assert.match(payload.htmlContent, /Mati City &middot; Davao Oriental/);
  assert.match(payload.htmlContent, /INFRASTRUCTURE<br>REPORTING/);
  assert.match(payload.htmlContent, /font-family:'Archivo Expanded'/);
  assert.match(payload.htmlContent, /<span style="color:#0e3a4c;">Infra<\/span>/);
  assert.match(payload.htmlContent, /<span style="color:#c1592b;">Track<\/span>/);
  assert.match(payload.htmlContent, /SECURITY ALERT/);
  assert.match(payload.htmlContent, /This email does not include your password\./);
  assert.match(payload.htmlContent, /Sign in to InfraTrack/);
  assert.doesNotMatch(payload.htmlContent, /LOCAL GOVERNMENT UNIT/);
});

test("reports when email delivery is not configured", async () => {
  const result = await sendEmailNotification(
    { recipient: "staff@example.com", subject: "Password changed", body: "Your password was changed." },
    { env: {}, fetchImpl: async () => assert.fail("fetch should not be called") },
  );

  assert.deepEqual(result, { sent: false, configured: false, reason: "not_configured" });
});

test("does not report a failed Brevo response as a sent email", async () => {
  await assert.rejects(
    sendEmailNotification(
      { recipient: "staff@example.com", subject: "Password changed", body: "Your password was changed." },
      {
        env: { BREVO_API_KEY: "test-api-key", BREVO_SENDER_EMAIL: "no-reply@example.com" },
        fetchImpl: async () => ({ ok: false, status: 401 }),
      },
    ),
    /Brevo email request failed with status 401/,
  );
});

test("escapes message content before inserting it into the HTML email", () => {
  const html = renderBrandedEmail({
    subject: "<Welcome>",
    body: "Hello <script>alert('no')</script>\n\nYour account is ready & safe.",
  });

  assert.match(html, /&lt;Welcome&gt;/);
  assert.match(html, /&lt;script&gt;alert\(&#39;no&#39;\)&lt;\/script&gt;/);
  assert.match(html, /ready &amp; safe/);
  assert.doesNotMatch(html, /<script>/);
});

test("uses email-client-safe InfraTrack mark when the public logo URL is unavailable", () => {
  const html = renderBrandedEmail({
    subject: "Notice",
    body: "Message",
    logoUrl: "javascript:alert(1)",
  });

  assert.ok(html.includes("width=\"42\" height=\"42\""));
  assert.match(html, /border-collapse:collapse/);
  assert.match(html, /bgcolor="#ffffff"/);
  assert.match(html, /bgcolor="#c1592b"/);
  assert.doesNotMatch(html, /<svg\b/i);
  assert.match(html, /Mati City &middot; Davao Oriental/);
  assert.match(html, /color:#0e3a4c;">Infra/);
  assert.match(html, /color:#c1592b;">Track/);
  assert.doesNotMatch(html, /javascript:/);
});

test("renders a clean sign-in call to action and escaped security note", () => {
  const html = renderBrandedEmail({
    subject: "Account ready",
    body: "You can now sign in.",
    eyebrow: "ADMINISTRATOR ACCOUNT",
    note: "<admin@example.com> is your account. Keep your password private.",
    actionUrl: "https://infratrack.example.com/login",
    actionLabel: "Open InfraTrack",
  });

  assert.match(html, /ADMINISTRATOR ACCOUNT/);
  assert.match(html, /&lt;admin@example\.com&gt; is your account/);
  assert.match(html, /href="https:\/\/infratrack\.example\.com\/login"/);
  assert.match(html, /Open InfraTrack/);
  assert.doesNotMatch(html, /Account<\/td>/);

  const unsafeLink = renderBrandedEmail({
    subject: "Account ready",
    body: "You can now sign in.",
    actionUrl: "http://insecure.example.com",
    actionLabel: "Open InfraTrack",
  });
  assert.doesNotMatch(unsafeLink, /href="http:/);
  assert.doesNotMatch(unsafeLink, /Open InfraTrack/);
});
