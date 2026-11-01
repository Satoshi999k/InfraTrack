import test from "node:test";
import assert from "node:assert/strict";
import { shouldSeedDemoData } from "./seedPolicy.js";

test("demo seeding is disabled by default", () => {
  assert.equal(shouldSeedDemoData({ NODE_ENV: "development" }), false);
  assert.equal(shouldSeedDemoData({ NODE_ENV: "production" }), false);
});

test("demo seeding can only be explicitly enabled outside production", () => {
  assert.equal(
    shouldSeedDemoData({
      NODE_ENV: "development",
      SEED_DEMO_DATA: "true",
    }),
    true,
  );
  assert.throws(
    () =>
      shouldSeedDemoData({
        NODE_ENV: "production",
        SEED_DEMO_DATA: "true",
      }),
    /cannot be enabled in production/,
  );
});
