import { sendEmailNotification } from "./emailNotifications.js";

export function residentAccountCreatedEmail(user, { appUrl = "" } = {}) {
  return {
    recipient: user.email,
    subject: "Welcome to InfraTrack",
    body: `Hello ${user.name || "there"},\n\nYour InfraTrack account has been created. Complete identity verification in the app so the Mati City team can review your account and enable reporting features.\n\nIf you did not create this account, contact your Mati City administrator.`,
    template: {
      eyebrow: "ACCOUNT CREATED",
      note: "For your security, InfraTrack will never ask you to send your password by email.",
      actionUrl: appUrl,
      actionLabel: "Open InfraTrack",
    },
  };
}

export function residentAccountVerifiedEmail(user, { appUrl = "" } = {}) {
  return {
    recipient: user.email,
    subject: "Your InfraTrack account is verified",
    body: `Hello ${user.name || "there"},\n\nYour InfraTrack account has been verified. You can now submit community infrastructure reports and follow updates from the Mati City team.\n\nThank you for helping improve Mati City.`,
    template: {
      eyebrow: "ACCOUNT VERIFIED",
      note: "You can now sign in to InfraTrack and use the resident reporting features.",
      actionUrl: appUrl,
      actionLabel: "Open InfraTrack",
    },
  };
}

async function deliverAccountEmail(notification, email, user, logger) {
  try {
    const result = await email(notification);
    if (!result.sent) {
      logger.error(
        `Resident account email was not sent for account ${user.id} (${result.reason || "unknown delivery error"}).`,
      );
    } else {
      logger.info?.(
        `Resident account email sent for account ${user.id} via ${result.provider || "email provider"}.`,
      );
    }
    return result;
  } catch (error) {
    logger.error(
      `Resident account email failed for account ${user.id}:`,
      error.message,
    );
    return { sent: false, configured: true, reason: "delivery_failed" };
  }
}

export async function sendResidentAccountCreatedEmail(
  user,
  { appUrl = "", sendEmail = sendEmailNotification, logger = console } = {},
) {
  return deliverAccountEmail(
    residentAccountCreatedEmail(user, { appUrl }),
    sendEmail,
    user,
    logger,
  );
}

export async function sendResidentAccountVerifiedEmail(
  user,
  { appUrl = "", sendEmail = sendEmailNotification, logger = console } = {},
) {
  return deliverAccountEmail(
    residentAccountVerifiedEmail(user, { appUrl }),
    sendEmail,
    user,
    logger,
  );
}
