import test from "node:test";
import assert from "node:assert/strict";
import {
  isEmailNotificationConfigured,
  renderBrandedEmail,
  sendEmailNotification,
} from "./emailNotifications.js";

test("sends a transactional email through the EmailJS server API", async () => {
  let request;
  const result = await sendEmailNotification(
    {
      recipient: "resident@example.com",
      subject: "Password reset",
      body: "Your reset code is 123456.",
    },
    {
      env: {
        EMAILJS_SERVICE_ID: "service_test",
        EMAILJS_TEMPLATE_ID: "template_test",
        EMAILJS_PUBLIC_KEY: "test-public-key",
        EMAILJS_PRIVATE_KEY: "test-private-key",
        EMAILJS_FROM_NAME: "InfraTrack",
        EMAIL_LOGO_URL: "https://example.com/logo.png",
      },
      fetchImpl: async (url, options) => {
        request = { url, options };
        return { ok: true, status: 200 };
      },
    },
  );

  assert.deepEqual(result, {
    sent: true,
    configured: true,
    provider: "emailjs",
  });
  assert.equal(request.url, "https://api.emailjs.com/api/v1.0/email/send");
  const payload = JSON.parse(request.options.body);
  assert.equal(payload.service_id, "service_test");
  assert.equal(payload.template_id, "template_test");
  assert.equal(payload.user_id, "test-public-key");
  assert.equal(payload.accessToken, "test-private-key");
  assert.deepEqual(payload.template_params, {
    to_email: "resident@example.com",
    subject: "Password reset",
    message: "Your reset code is 123456.",
    html_content: renderBrandedEmail({
      subject: "Password reset",
      body: "Your reset code is 123456.",
      senderName: "InfraTrack",
      logoUrl: "https://example.com/logo.png",
      logoCid: "",
    }),
    from_name: "InfraTrack",
  });
  assert.match(payload.template_params.html_content, /InfraTrack/);
  assert.match(payload.template_params.html_content, /#0e3a4c/);
  assert.doesNotMatch(
    payload.template_params.html_content,
    /cid:infratrack-logo/,
  );
});

test("EmailJS is configured only when all server credentials and template IDs exist", () => {
  assert.equal(
    isEmailNotificationConfigured({
      EMAILJS_SERVICE_ID: "service_test",
      EMAILJS_TEMPLATE_ID: "template_test",
      EMAILJS_PUBLIC_KEY: "test-public-key",
    }),
    false,
  );
  assert.equal(
    isEmailNotificationConfigured({
      EMAILJS_SERVICE_ID: "service_test",
      EMAILJS_TEMPLATE_ID: "template_test",
      EMAILJS_PUBLIC_KEY: "test-public-key",
      EMAILJS_PRIVATE_KEY: "test-private-key",
    }),
    true,
  );
});

test("renders a prominent escaped reset code and security notice in the branded email", () => {
  const html = renderBrandedEmail({
    subject: "Your InfraTrack password reset code",
    body: "Hello Marlo,\n\nEnter the code below to reset your password.\n\nThanks,\nThe InfraTrack Team",
    eyebrow: "PASSWORD RESET",
    code: "169270",
    codeLabel: "PASSWORD RESET CODE",
    note: "This code expires in 10 minutes.",
  });

  assert.match(html, /PASSWORD RESET CODE/);
  assert.match(html, /letter-spacing:8px/);
  assert.match(html, />169270<\/td>/);
  assert.match(html, /Security notice:/);
  assert.match(html, /The InfraTrack Team/);

  const escapedCode = renderBrandedEmail({
    subject: "Reset",
    body: "Message",
    code: "<123456>",
  });
  assert.match(escapedCode, /&lt;123456&gt;/);
  assert.doesNotMatch(escapedCode, /<123456>/);
});

test("sends a transactional email through the Resend HTTPS API", async () => {
  let request;
  const result = await sendEmailNotification(
    {
      recipient: "resident@example.com",
      subject: "Your password reset code",
      body: "Your reset code is 123456.",
    },
    {
      env: {
        RESEND_API_KEY: "test-resend-key",
        RESEND_FROM_EMAIL: "no-reply@example.com",
        RESEND_FROM_NAME: "InfraTrack",
        EMAIL_LOGO_URL: "https://example.com/infratrack-logo.png",
      },
      fetchImpl: async (url, options) => {
        request = { url, options };
        return {
          ok: true,
          status: 200,
          json: async () => ({ id: "resend-message-id" }),
        };
      },
    },
  );

  assert.equal(result.sent, true);
  assert.equal(result.provider, "resend");
  assert.equal(result.messageId, "resend-message-id");
  assert.equal(request.url, "https://api.resend.com/emails");
  assert.equal(request.options.headers.Authorization, "Bearer test-resend-key");
  const payload = JSON.parse(request.options.body);
  assert.equal(payload.from, "InfraTrack <no-reply@example.com>");
  assert.deepEqual(payload.to, ["resident@example.com"]);
  assert.equal(payload.subject, "Your password reset code");
  assert.equal(payload.text, "Your reset code is 123456.");
  assert.match(payload.html, /Your reset code is 123456\./);
  assert.doesNotMatch(request.options.body, /test-resend-key/);
});

test("requires a sender address before marking Resend as configured", () => {
  assert.equal(
    isEmailNotificationConfigured({ RESEND_API_KEY: "test-resend-key" }),
    false,
  );
  assert.equal(
    isEmailNotificationConfigured({
      RESEND_API_KEY: "test-resend-key",
      RESEND_FROM_EMAIL: "no-reply@example.com",
    }),
    true,
  );
});

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
