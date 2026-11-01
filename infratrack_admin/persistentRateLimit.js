import { createHash } from "node:crypto";

export async function consumePersistentRateLimit(
  pool,
  key,
  { limit, windowSeconds },
) {
  if (!Number.isInteger(limit) || limit < 1) {
    throw new TypeError("Rate-limit limit must be a positive integer.");
  }
  if (!Number.isInteger(windowSeconds) || windowSeconds < 1) {
    throw new TypeError("Rate-limit window must be a positive integer.");
  }

  const bucketKey = createHash("sha256").update(String(key)).digest("hex");
  await pool.query(
    `INSERT INTO api_rate_limits (bucket_key, attempt_count, window_started_at)
     VALUES (?, 1, CURRENT_TIMESTAMP)
     ON DUPLICATE KEY UPDATE
       attempt_count = IF(
         window_started_at <= TIMESTAMPADD(SECOND, -?, CURRENT_TIMESTAMP),
         1,
         attempt_count + 1
       ),
       window_started_at = IF(
         window_started_at <= TIMESTAMPADD(SECOND, -?, CURRENT_TIMESTAMP),
         CURRENT_TIMESTAMP,
         window_started_at
       )`,
    [bucketKey, windowSeconds, windowSeconds],
  );
  const [[bucket]] = await pool.query(
    "SELECT attempt_count FROM api_rate_limits WHERE bucket_key = ?",
    [bucketKey],
  );

  return Number(bucket?.attempt_count) <= limit;
}

export async function clearPersistentRateLimit(pool, key) {
  const bucketKey = createHash("sha256").update(String(key)).digest("hex");
  await pool.query("DELETE FROM api_rate_limits WHERE bucket_key = ?", [
    bucketKey,
  ]);
}
