const escapeHtml = (value) =>
  String(value)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#39;");

function getPublicLogoUrl(value) {
  try {
    const logoUrl = new URL(value);
    return logoUrl.protocol === "https:" ? escapeHtml(logoUrl.href) : "";
  } catch {
    return "";
  }
}

function createEmailSafeBrandMark() {
  const rows = [
    ".....W.....",
    "....WWW....",
    "...WWWWW...",
    "..WWWWWWW..",
    ".WWWWWWWWW.",
    ".WWWOWOWWW.",
    ".WWOWWWOWW.",
    ".WWWOWOWWW.",
    "..WWWWWWW..",
    "...WWWWW...",
    "....WWW....",
    ".....W.....",
  ];
  const cells = rows
    .map(
      (row) =>
        `<tr>${[...row]
          .map((pixel) => {
            const color = pixel === "W" ? "#ffffff" : pixel === "O" ? "#c1592b" : "";
            return `<td width="2" height="2"${color ? ` bgcolor="${color}"` : ""} style="width:2px;height:2px;font-size:0;line-height:2px;${color ? `background-color:${color};` : ""}">&nbsp;</td>`;
          })
          .join("")}</tr>`,
    )
    .join("");

  return `<table role="presentation" width="42" height="42" cellspacing="0" cellpadding="0" border="0" style="width:42px;height:42px;border:1px solid #d97b53;border-radius:12px;background-color:#c1592b;"><tr><td align="center" valign="middle"><table role="presentation" cellspacing="0" cellpadding="0" border="0" style="border-collapse:collapse;">${cells}</table></td></tr></table>`;
}

export function renderBrandedEmail({
  subject,
  body,
  senderName = "InfraTrack",
  logoUrl = "",
  eyebrow = "",
  note = "",
  actionUrl = "",
  actionLabel = "",
}) {
  const paragraphs = String(body)
    .trim()
    .split(/\n\s*\n/)
    .filter(Boolean)
    .map((paragraph) => `<p style="margin:0 0 18px;color:#52645f;font-family:Arial,Helvetica,sans-serif;font-size:15px;line-height:1.75;">${escapeHtml(paragraph).replaceAll("\n", "<br>")}</p>`)
    .join("");
  const preheader = escapeHtml(String(body).trim().split(/\r?\n/, 1)[0] || subject);
  const safeLogoUrl = getPublicLogoUrl(logoUrl);
  const safeActionUrl = getPublicLogoUrl(actionUrl);
  const brandMark = safeLogoUrl
    ? `<img src="${safeLogoUrl}" width="40" height="40" alt="${escapeHtml(senderName)} logo" style="display:block;width:40px;height:40px;object-fit:contain;border-radius:12px;">`
    : `<table role="presentation" width="42" height="42" cellspacing="0" cellpadding="0" border="0" style="width:42px;height:42px;border:1px solid #d97b53;border-radius:12px;background-color:#c1592b;"><tr><td align="center" valign="middle"><svg xmlns="http://www.w3.org/2000/svg" width="26" height="26" viewBox="0 0 24 24" role="img" aria-label="InfraTrack location and services mark"><path fill="#ffffff" d="M12 2C8.13 2 5 5.13 5 9c0 5.25 7 13 7 13s7-7.75 7-13c0-3.87-3.13-7-7-7Zm0 9.5A2.5 2.5 0 1 1 12 6.5a2.5 2.5 0 0 1 0 5Z"/><path fill="#ffffff" d="M19 1a1 1 0 0 1 1 1v2h2a1 1 0 1 1 0 2h-2v2a1 1 0 1 1-2 0V6h-2a1 1 0 1 1 0-2h2V2a1 1 0 0 1 1-1Z"/></svg></td></tr></table>`;
  const eyebrowContent = eyebrow
    ? `<div style="margin:0 0 9px;color:#1b8a83;font-family:Arial,Helvetica,sans-serif;font-size:10px;font-weight:bold;letter-spacing:1.1px;text-transform:uppercase;">${escapeHtml(eyebrow)}</div>`
    : "";
  const securityNote = note
    ? `<table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0" style="margin:23px 0 4px;border-left:3px solid #1b8a83;background-color:#f2f7f5;">
        <tr><td valign="top" width="38" style="padding:15px 0 15px 15px;">
          <div style="width:20px;height:20px;border-radius:50%;background-color:#dcefe9;color:#0e6863;font-family:Arial,Helvetica,sans-serif;font-size:13px;font-weight:bold;line-height:20px;text-align:center;">i</div>
        </td><td style="padding:14px 15px 14px 0;color:#52645f;font-family:Arial,Helvetica,sans-serif;font-size:13px;line-height:1.6;">${escapeHtml(note)}</td></tr>
      </table>`
    : "";
  const actionButton = safeActionUrl && actionLabel
    ? `<table role="presentation" cellspacing="0" cellpadding="0" border="0" style="margin:24px 0 0;">
        <tr><td align="center" style="border-radius:8px;background-color:#c1592b;">
          <a href="${safeActionUrl}" style="display:inline-block;padding:13px 22px;border:1px solid #c1592b;border-radius:8px;color:#ffffff;font-family:Arial,Helvetica,sans-serif;font-size:14px;font-weight:bold;text-decoration:none;">${escapeHtml(actionLabel)}</a>
        </td></tr>
      </table>`
    : "";

  return `<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width,initial-scale=1">
    <meta name="color-scheme" content="light">
    <meta name="supported-color-schemes" content="light">
    <title>${escapeHtml(subject)}</title>
    <style>
      @media only screen and (max-width:600px) {
        .email-shell { padding:14px 8px !important; }
        .email-card { border-radius:12px !important; }
        .email-header { padding:18px 20px !important; }
        .email-content { padding:30px 22px 22px !important; }
        .email-footer-content { padding:18px 22px 22px !important; }
        .email-title { font-size:27px !important; }
        .email-location { display:none !important; }
      }
    </style>
  </head>
  <body style="margin:0;padding:0;background-color:#f3efe6;">
    <div style="display:none;max-height:0;overflow:hidden;opacity:0;color:transparent;">${preheader}</div>
    <table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0" style="background-color:#f3efe6;">
      <tr>
        <td class="email-shell" align="center" style="padding:42px 18px;">
          <table role="presentation" class="email-card" width="600" cellspacing="0" cellpadding="0" border="0" style="width:100%;max-width:600px;border:1px solid #ded9ce;border-radius:12px;background-color:#ffffff;overflow:hidden;">
            <tr>
              <td style="height:4px;background-color:#c1592b;font-size:1px;line-height:4px;">&nbsp;</td>
            </tr>
            <tr>
              <td class="email-header" style="padding:21px 30px 19px;background-color:#ffffff;">
                <table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0">
                  <tr>
                    <td width="52" valign="middle">${safeLogoUrl ? brandMark : createEmailSafeBrandMark()}</td>
                    <td valign="middle" style="padding-left:8px;font-family:'Archivo Expanded','Arial Black',Arial,Helvetica,sans-serif;font-size:21px;font-weight:800;letter-spacing:-1px;white-space:nowrap;">
                      <span style="color:#0e3a4c;">Infra</span><span style="color:#c1592b;">Track</span>
                      <div style="padding-top:5px;color:#1b8a83;font-family:Arial,Helvetica,sans-serif;font-size:9px;font-weight:bold;letter-spacing:1.4px;text-transform:uppercase;">Mati City &middot; Davao Oriental</div>
                    </td>
                    <td class="email-location" align="right" valign="middle" style="color:#718078;font-family:Arial,Helvetica,sans-serif;font-size:10px;font-weight:bold;letter-spacing:1px;text-transform:uppercase;">INFRASTRUCTURE<br>REPORTING</td>
                  </tr>
                </table>
              </td>
            </tr>
            <tr>
              <td class="email-content" style="padding:38px 42px 30px;">
                ${eyebrowContent}
                <h1 class="email-title" style="margin:0 0 20px;color:#0e3a4c;font-family:Arial,Helvetica,sans-serif;font-size:29px;font-weight:700;line-height:1.25;letter-spacing:-.45px;">${escapeHtml(subject)}</h1>
                ${paragraphs}
                ${actionButton}
                ${securityNote}
              </td>
            </tr>
            <tr>
              <td class="email-footer-content" style="padding:18px 42px 21px;border-top:1px solid #e8e3d9;background-color:#faf9f5;color:#66766f;font-family:Arial,Helvetica,sans-serif;font-size:12px;line-height:1.65;">
                Contact your Mati City system administrator if you need help.<br>
                <span style="color:#87918a;">Automated message from ${escapeHtml(senderName)}. Please do not reply.</span>
              </td>
            </tr>
          </table>
          <div style="padding:14px 12px 0;color:#718078;font-family:Arial,Helvetica,sans-serif;font-size:10px;line-height:1.6;text-align:center;">InfraTrack &middot; Mati City, Davao Oriental</div>
        </td>
      </tr>
    </table>
  </body>
</html>`;
}

export async function sendEmailNotification(
  { recipient, subject, body, template = {} },
  { env = process.env, fetchImpl = fetch } = {},
) {
  if (!recipient) {
    return { sent: false, configured: false, reason: "missing_recipient" };
  }

  if (env.BREVO_API_KEY) {
    if (!env.BREVO_SENDER_EMAIL) {
      return { sent: false, configured: false, reason: "missing_sender" };
    }

    const senderName = env.BREVO_SENDER_NAME || "InfraTrack";
    const response = await fetchImpl("https://api.brevo.com/v3/smtp/email", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "api-key": env.BREVO_API_KEY,
      },
      body: JSON.stringify({
        sender: {
          name: senderName,
          email: env.BREVO_SENDER_EMAIL,
        },
        to: [{ email: recipient }],
        subject,
        textContent: body,
        htmlContent: renderBrandedEmail({
          subject,
          body,
          senderName,
          logoUrl: env.BREVO_LOGO_URL,
          ...template,
        }),
      }),
    });

    if (!response.ok) {
      throw new Error(`Brevo email request failed with status ${response.status}`);
    }

    return { sent: true, configured: true, provider: "brevo" };
  }

  if (env.EMAIL_NOTIFICATION_WEBHOOK) {
    const response = await fetchImpl(env.EMAIL_NOTIFICATION_WEBHOOK, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        channel: "email",
        recipient,
        subject,
        body,
        htmlContent: renderBrandedEmail({
          subject,
          body,
          senderName: env.BREVO_SENDER_NAME || "InfraTrack",
          logoUrl: env.BREVO_LOGO_URL,
          ...template,
        }),
      }),
    });

    if (!response.ok) {
      throw new Error(`Email notification webhook failed with status ${response.status}`);
    }

    return { sent: true, configured: true, provider: "webhook" };
  }

  return { sent: false, configured: false, reason: "not_configured" };
}
