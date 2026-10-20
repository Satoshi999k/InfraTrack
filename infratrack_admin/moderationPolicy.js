export const suspensionDurations = Object.freeze({
  "24 hours": 24,
  "3 days": 72,
  "7 days": 168,
  "14 days": 336,
  "30 days": 720,
  Permanent: null,
});

export function suspensionHours(duration) {
  if (!Object.hasOwn(suspensionDurations, duration)) {
    throw new Error("Choose a valid suspension duration.");
  }
  return suspensionDurations[duration];
}

export function standingAfterModeration(action, currentStanding = "Active") {
  if (action === "warn") return currentStanding;
  if (action === "suspend") return "Suspended";
  if (action === "ban") return "Banned";
  if (action === "restore") return "Active";
  throw new Error("Choose a valid moderation action.");
}

export function moderationNotification(action, duration) {
  if (action === "warn") {
    return {
      title: "Account warning",
      message:
        "You have received a warning for a community-guideline violation. Your account remains active. Further violations may lead to a temporary suspension or ban.",
    };
  }
  if (action === "suspend") {
    const permanent = duration === "Permanent";
    const period =
      permanent ? "until an administrator restores access" : `for ${duration}`;
    return {
      title: permanent
        ? "Reporting access suspended"
        : "Reporting temporarily suspended",
      message: `You cannot submit reports ${period}. You can continue using other parts of InfraTrack.`,
    };
  }
  if (action === "ban") {
    return {
      title: "InfraTrack account banned",
      message:
        "Your account has been banned from InfraTrack. You will be signed out and cannot sign in while the ban is in effect.",
    };
  }
  return {
    title: "Account access restored",
    message: "Your InfraTrack account is active again and report submissions are available.",
  };
}
