export const FCM_MULTICAST_BATCH_SIZE = 500;
export function splitFcmTokens(tokens) {
  const batches = [];
  for (let offset = 0; offset < tokens.length; offset += FCM_MULTICAST_BATCH_SIZE) {
    batches.push(tokens.slice(offset, offset + FCM_MULTICAST_BATCH_SIZE));
  }
  return batches;
}

export function createAndroidDeliveryConfig(imageUrl = null) {
  return {
    priority: "high",
    notification: {
      channelId: "infratrack_city_updates_v3",
      sound: "default",
      ...(imageUrl ? { imageUrl } : {}),
    },
  };
}
