import test from "node:test";
import assert from "node:assert/strict";
import { serializeAdminAuthUser } from "./authUser.js";

test("login user response includes the saved profile photo without exposing credentials", () => {
  const user = serializeAdminAuthUser({
    id: 12,
    name: "City Administrator",
    email: "admin@infratrack.test",
    barangay: "Mati City",
    avatar_url: "https://images.example.test/profile.jpg",
    role: "admin",
    standing: "Active",
    suspended_until: null,
    password_hash: "sensitive-hash",
  });

  assert.deepEqual(user, {
    id: 12,
    name: "City Administrator",
    email: "admin@infratrack.test",
    barangay: "Mati City",
    avatar_url: "https://images.example.test/profile.jpg",
    role: "admin",
    standing: "Active",
    suspended_until: null,
  });
  assert.equal("password_hash" in user, false);
});

test("login user response accepts a request-resolved profile photo URL", () => {
  const user = serializeAdminAuthUser(
    { id: 12, avatar_url: "/uploads/profile.jpg" },
    "https://admin.example.test/uploads/profile.jpg",
  );

  assert.equal(user.avatar_url, "https://admin.example.test/uploads/profile.jpg");
});
