import test from "node:test";
import assert from "node:assert/strict";
import {
  createAndroidDeliveryConfig,
  splitFcmTokens,
} from "./fcmDelivery.js";

test("FCM tokens are split into Firebase multicast batches", () => {
  const tokens = Array.from({ length: 501 }, (_, index) => `token-${index}`);

  const batches = splitFcmTokens(tokens);

  assert.equal(batches.length, 2);
  assert.equal(batches[0].length, 500);
  assert.equal(batches[1].length, 1);
});

test("Android push delivery uses high priority and no delivery delay", () => {
  assert.deepEqual(createAndroidDeliveryConfig("https://example.com/image.jpg"), {
    priority: "high",
    ttl: "0s",
    notification: {
      channelId: "infratrack_city_updates_v3",
      sound: "default",
      imageUrl: "https://example.com/image.jpg",
    },
  });
});
