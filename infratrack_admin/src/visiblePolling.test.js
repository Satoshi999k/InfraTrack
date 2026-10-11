import test from "node:test";
import assert from "node:assert/strict";

import { startVisiblePolling } from "./visiblePolling.js";

function createPollingHarness(visibilityState = "visible") {
  const listeners = new Map();
  let intervalCallback;
  let clearedInterval;
  let intervalDelay;

  return {
    documentRef: {
      visibilityState,
      addEventListener: (event, callback) => listeners.set(event, callback),
      removeEventListener: (event) => listeners.delete(event),
    },
    setIntervalFn: (callback, delay) => {
      intervalCallback = callback;
      intervalDelay = delay;
      return 7;
    },
    clearIntervalFn: (id) => {
      clearedInterval = id;
    },
    tick: () => intervalCallback(),
    changeVisibility(state) {
      this.documentRef.visibilityState = state;
      listeners.get("visibilitychange")?.();
    },
    get intervalDelay() {
      return intervalDelay;
    },
    get clearedInterval() {
      return clearedInterval;
    },
    hasVisibilityListener: () => listeners.has("visibilitychange"),
  };
}

const flushAsync = () => new Promise((resolve) => setImmediate(resolve));

test("polls immediately and uses the configured slower interval", async () => {
  const harness = createPollingHarness();
  let calls = 0;

  const stop = startVisiblePolling(
    () => {
      calls += 1;
    },
    {
      documentRef: harness.documentRef,
      intervalMs: 30_000,
      setIntervalFn: harness.setIntervalFn,
      clearIntervalFn: harness.clearIntervalFn,
    },
  );

  assert.equal(calls, 1);
  assert.equal(harness.intervalDelay, 30_000);
  harness.tick();
  await flushAsync();
  assert.equal(calls, 1);
  harness.tick();
  await flushAsync();
  assert.equal(calls, 2);
  stop();
});

test("pauses while hidden and refreshes as soon as the tab becomes visible", async () => {
  const harness = createPollingHarness("hidden");
  let calls = 0;

  const stop = startVisiblePolling(
    () => {
      calls += 1;
    },
    {
      documentRef: harness.documentRef,
      intervalMs: 30_000,
      setIntervalFn: harness.setIntervalFn,
      clearIntervalFn: harness.clearIntervalFn,
    },
  );

  harness.tick();
  assert.equal(calls, 0);
  harness.changeVisibility("visible");
  await flushAsync();
  assert.equal(calls, 1);
  stop();
});

test("does not overlap refreshes and cleans up its timer and visibility listener", async () => {
  const harness = createPollingHarness();
  let calls = 0;
  let finishRefresh;
  const refreshInProgress = new Promise((resolve) => {
    finishRefresh = resolve;
  });

  const stop = startVisiblePolling(
    () => {
      calls += 1;
      return calls === 1 ? refreshInProgress : undefined;
    },
    {
      documentRef: harness.documentRef,
      intervalMs: 30_000,
      setIntervalFn: harness.setIntervalFn,
      clearIntervalFn: harness.clearIntervalFn,
    },
  );

  harness.tick();
  assert.equal(calls, 1);
  finishRefresh();
  await flushAsync();
  harness.tick();
  await flushAsync();
  assert.equal(calls, 2);

  stop();
  assert.equal(harness.clearedInterval, 7);
  assert.equal(harness.hasVisibilityListener(), false);
  harness.tick();
  assert.equal(calls, 2);
});
