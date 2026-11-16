import test from "node:test";
import assert from "node:assert/strict";
import { apiFetch } from "./api.js";

function createStorage(values = {}) {
  const storage = new Map(Object.entries(values));
  return {
    getItem(key) {
      return storage.get(key) ?? null;
    },
  };
}

test("authenticated API requests announce expired sessions on 401 responses", async () => {
  const originalFetch = globalThis.fetch;
  const originalWindow = globalThis.window;
  const originalLocalStorage = globalThis.localStorage;
  const originalSessionStorage = globalThis.sessionStorage;
  const eventTarget = new EventTarget();
  let expiredEvents = 0;
  eventTarget.addEventListener("infratrack:session-expired", () => {
    expiredEvents += 1;
  });
  globalThis.window = eventTarget;
  globalThis.localStorage = createStorage({ "infratrack.adminToken": "expired" });
  globalThis.sessionStorage = createStorage();
  globalThis.fetch = async () => new Response(null, { status: 401 });

  try {
    const response = await apiFetch("/mobile/notifications");
    assert.equal(response.status, 401);
    assert.equal(expiredEvents, 1);
  } finally {
    globalThis.fetch = originalFetch;
    globalThis.window = originalWindow;
    globalThis.localStorage = originalLocalStorage;
    globalThis.sessionStorage = originalSessionStorage;
  }
});

test("authenticated API requests do not announce expired sessions for other responses", async () => {
  const originalFetch = globalThis.fetch;
  const originalWindow = globalThis.window;
  const originalLocalStorage = globalThis.localStorage;
  const originalSessionStorage = globalThis.sessionStorage;
  const eventTarget = new EventTarget();
  let expiredEvents = 0;
  eventTarget.addEventListener("infratrack:session-expired", () => {
    expiredEvents += 1;
  });
  globalThis.window = eventTarget;
  globalThis.localStorage = createStorage();
  globalThis.sessionStorage = createStorage({
    "infratrack.adminToken": "valid",
  });
  globalThis.fetch = async () => new Response(null, { status: 403 });

  try {
    const response = await apiFetch("/mobile/notifications");
    assert.equal(response.status, 403);
    assert.equal(expiredEvents, 0);
  } finally {
    globalThis.fetch = originalFetch;
    globalThis.window = originalWindow;
    globalThis.localStorage = originalLocalStorage;
    globalThis.sessionStorage = originalSessionStorage;
  }
});

test("late 401 responses do not expire a session that has already changed", async () => {
  const originalFetch = globalThis.fetch;
  const originalWindow = globalThis.window;
  const originalLocalStorage = globalThis.localStorage;
  const originalSessionStorage = globalThis.sessionStorage;
  const eventTarget = new EventTarget();
  let expiredEvents = 0;
  eventTarget.addEventListener("infratrack:session-expired", () => {
    expiredEvents += 1;
  });
  globalThis.window = eventTarget;
  globalThis.localStorage = createStorage({ "infratrack.adminToken": "old" });
  globalThis.sessionStorage = createStorage();
  let resolveResponse;
  globalThis.fetch = () =>
    new Promise((resolve) => {
      resolveResponse = resolve;
    });

  try {
    const responsePromise = apiFetch("/mobile/notifications");
    globalThis.localStorage = createStorage({
      "infratrack.adminToken": "new",
    });
    resolveResponse(new Response(null, { status: 401 }));

    await responsePromise;
    assert.equal(expiredEvents, 0);
  } finally {
    globalThis.fetch = originalFetch;
    globalThis.window = originalWindow;
    globalThis.localStorage = originalLocalStorage;
    globalThis.sessionStorage = originalSessionStorage;
  }
});
