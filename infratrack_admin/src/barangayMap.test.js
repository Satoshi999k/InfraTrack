import test from "node:test";
import assert from "node:assert/strict";

import { getBarangayMapCenter } from "./barangayMap.js";

test("centers Central staff accounts on Barangay Central", () => {
  assert.deepEqual(getBarangayMapCenter("Barangay Central"), [
    6.9612515, 126.2069944,
  ]);
  assert.deepEqual(getBarangayMapCenter("Brgy. Central"), [
    6.9612515, 126.2069944,
  ]);
});

test("centers staff accounts at their assigned barangay", () => {
  assert.deepEqual(getBarangayMapCenter("Dawan"), [6.8993278, 126.15106]);
  assert.deepEqual(getBarangayMapCenter("Brgy. Dahican"), [
    6.9466732, 126.2603384,
  ]);
});

test("returns no barangay center for unknown or city-wide accounts", () => {
  assert.equal(getBarangayMapCenter("Mati City"), null);
  assert.equal(getBarangayMapCenter("Unknown Barangay"), null);
});
