import test from "node:test";
import assert from "node:assert/strict";

import { verificationApprovalNotification } from "./verificationNotifications.js";

test("creates a welcome notification when verification is approved", () => {
  assert.deepEqual(verificationApprovalNotification("Pending ID match"), {
    type: "account",
    title: "You're verified - welcome to InfraTrack!",
    message:
      "Your account has been approved. You can now submit community reports and follow updates from the Mati City team.",
  });
});

test("does not create a duplicate welcome notification for an already verified account", () => {
  assert.equal(verificationApprovalNotification("Verified"), null);
  assert.equal(verificationApprovalNotification(" verified "), null);
});
