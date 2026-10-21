export function verificationApprovalNotification(previousVerification) {
  if (String(previousVerification ?? "").trim().toLowerCase() === "verified") {
    return null;
  }
  return {
    type: "account",
    title: "You're verified - welcome to InfraTrack!",
    message:
      "Your account has been approved. You can now submit community reports and follow updates from the Mati City team.",
  };
}
