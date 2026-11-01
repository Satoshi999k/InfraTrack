import test from "node:test";
import assert from "node:assert/strict";
import {
  clearPersistentRateLimit,
  consumePersistentRateLimit,
} from "./persistentRateLimit.js";

test("persistent rate limits hash bucket keys before storing them", async () => {
  const queries = [];
  const pool = {
    async query(sql, params) {
      queries.push({ sql, params });
      if (sql.startsWith("SELECT")) return [[{ attempt_count: 2 }]];
      return [{ affectedRows: 1 }];
    },
  };

  assert.equal(
    await consumePersistentRateLimit(pool, "login:192.0.2.10", {
      limit: 5,
      windowSeconds: 900,
    }),
    true,
  );
  assert.match(queries[0].params[0], /^[a-f0-9]{64}$/);
  assert.equal(queries[0].params[1], 900);
  assert.equal(queries[0].params[2], 900);
});

test("persistent rate limits reject attempts beyond the configured threshold", async () => {
  const pool = {
    async query(sql) {
      if (sql.startsWith("SELECT")) return [[{ attempt_count: 6 }]];
      return [{ affectedRows: 1 }];
    },
  };

  assert.equal(
    await consumePersistentRateLimit(pool, "login:192.0.2.10", {
      limit: 5,
      windowSeconds: 900,
    }),
    false,
  );
});

test("persistent rate-limit buckets can be cleared after successful login", async () => {
  let deletedKey;
  const pool = {
    async query(sql, params) {
      assert.match(sql, /^DELETE FROM api_rate_limits/);
      deletedKey = params[0];
      return [{ affectedRows: 1 }];
    },
  };

  await clearPersistentRateLimit(pool, "login:192.0.2.10");

  assert.match(deletedKey, /^[a-f0-9]{64}$/);
});
