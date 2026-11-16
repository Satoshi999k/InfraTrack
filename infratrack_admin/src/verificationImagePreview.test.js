import test from "node:test";
import assert from "node:assert/strict";
import { createVerificationImagePreview } from "./verificationImagePreview.js";

test("verification preview keeps the selected image and its label", () => {
  assert.deepEqual(
    createVerificationImagePreview(
      "https://media.example/id-front.jpg",
      "National ID · front",
    ),
    {
      src: "https://media.example/id-front.jpg",
      label: "National ID · front",
    },
  );
});

test("verification preview is not created without an image", () => {
  assert.equal(createVerificationImagePreview("", "Live selfie"), null);
});
