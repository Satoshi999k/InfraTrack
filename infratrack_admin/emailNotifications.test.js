import test from "node:test";
import assert from "node:assert/strict";
import {
  renderBrandedEmail,
  sendEmailNotification,
} from "./emailNotifications.js";

test("sends a transactional email through authenticated SSL/TLS SMTP", async () => {
  let transportConfig;
  let message;
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
        SMTP_HOST: "mail.example.com",
        SMTP_PORT: "465",
        SMTP_USER: "no-reply@example.com",
        SMTP_PASSWORD: "test-password",
        SMTP_FROM_NAME: "InfraTrack",
        EMAIL_LOGO_URL: "https://example.com/infratrack-logo.png",
      },
      createTransportImpl: (config) => {
        transportConfig = config;
        return {
          sendMail: async (outgoingMessage) => {
            message = outgoingMessage;
            return { messageId: "smtp-message-id" };
          },
        };
      },
    },
  );

  assert.equal(result.sent, true);
  assert.equal(result.provider, "smtp");
  assert.equal(result.messageId, "smtp-message-id");
  assert.deepEqual(transportConfig, {
    host: "mail.example.com",
    port: 465,
    secure: true,
    auth: { user: "no-reply@example.com", pass: "test-password" },
  });
  assert.deepEqual(message.from, {
    name: "InfraTrack",
    address: "no-reply@example.com",
  });
  assert.equal(message.to, "staff@example.com");
  assert.equal(message.subject, "Password changed");
  assert.equal(message.text, "Your password was changed.");
  assert.equal(
    message.html,
    renderBrandedEmail({
      subject: "Password changed",
      body: "Your password was changed.",
      senderName: "InfraTrack",
      logoUrl: "https://example.com/infratrack-logo.png",
      eyebrow: "SECURITY ALERT",
      note: "This email does not include your password.",
      actionUrl: "https://infratrack.example.com",
      actionLabel: "Sign in to InfraTrack",
    }),
  );
  assert.match(message.html, /<!doctype html>/i);
  assert.match(message.html, /Your password was changed\./);
  assert.match(message.html, /https:\/\/example\.com\/infratrack-logo\.png/);
  assert.match(message.html, /#0e3a4c/);
  assert.match(message.html, /#1b8a83/);
  assert.match(message.html, /#c1592b/);
  assert.match(message.html, /#f3efe6/);
  assert.match(message.html, /Mati City &middot; Davao Oriental/);
  assert.match(message.html, /INFRASTRUCTURE<br>REPORTING/);
  assert.match(message.html, /font-family:'Archivo Expanded'/);
  assert.match(message.html, /<span style="color:#0e3a4c;">Infra<\/span>/);
  assert.match(message.html, /<span style="color:#c1592b;">Track<\/span>/);
  assert.match(message.html, /SECURITY ALERT/);
  assert.match(message.html, /This email does not include your password\./);
  assert.match(message.html, /Sign in to InfraTrack/);
  assert.doesNotMatch(message.html, /LOCAL GOVERNMENT UNIT/);
});

test("reports when email delivery is not configured", async () => {
  const result = await sendEmailNotification(
    {
      recipient: "staff@example.com",
      subject: "Password changed",
      body: "Your password was changed.",
    },
    {
      env: {},
      fetchImpl: async () => assert.fail("fetch should not be called"),
    },
  );

  assert.deepEqual(result, {
    sent: false,
    configured: false,
    reason: "not_configured",
  });
});

test("embeds the supplied InfraTrack logo in SMTP emails when no public logo URL is set", async () => {
  let message;
  await sendEmailNotification(
    {
      recipient: "resident@example.com",
      subject: "Welcome",
      body: "Your account is ready.",
    },
    {
      env: {
        SMTP_HOST: "mail.example.com",
        SMTP_USER: "no-reply@example.com",
        SMTP_PASSWORD: "test-password",
      },
      createTransportImpl: () => ({
        sendMail: async (outgoingMessage) => {
          message = outgoingMessage;
          return { messageId: "smtp-message-id" };
        },
      }),
    },
  );

  assert.equal(message.attachments[0].filename, "infratrack-logo.png");
  assert.equal(message.attachments[0].cid, "infratrack-logo");
  assert.match(message.html, /src="cid:infratrack-logo"/);
  assert.ok(message.attachments[0].content.byteLength > 0);
});

test("does not report a failed SMTP delivery as a sent email", async () => {
  await assert.rejects(
    sendEmailNotification(
      {
        recipient: "staff@example.com",
        subject: "Password changed",
        body: "Your password was changed.",
      },
      {
        env: {
          SMTP_HOST: "mail.example.com",
          SMTP_USER: "no-reply@example.com",
          SMTP_PASSWORD: "test-password",
        },
        createTransportImpl: () => ({
          sendMail: async () => {
            throw new Error("SMTP connection failed");
          },
        }),
      },
    ),
    /SMTP connection failed/,
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

  assert.ok(html.includes('width="42" height="42"'));
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
