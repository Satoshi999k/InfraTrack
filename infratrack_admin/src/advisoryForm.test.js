import test from "node:test";
import assert from "node:assert/strict";

import {
  getNewsCarouselFeaturedCount,
  getAdvisoryAudience,
  isNewsCarouselOnlyUpdate,
  isNewsCarouselFeatured,
  applyNewsCarouselSelection,
  mergeCreatedAdvisory,
  getFeaturedNewsCarouselAdvisories,
  validateAdvisoryDraft,
  validateNewsCarouselFeature,
} from "./advisoryForm.js";

test("news carousel selection updates the advisory in local state immediately", () => {
  const advisories = [{ id: 7, featured_in_news: 0 }, { id: 8, featured_in_news: 1 }];
  assert.deepEqual(
    applyNewsCarouselSelection(advisories, 7, true),
    [{ id: 7, featured_in_news: true }, { id: 8, featured_in_news: 1 }],
  );
  assert.deepEqual(
    applyNewsCarouselSelection(advisories, 8, false),
    [{ id: 7, featured_in_news: 0 }, { id: 8, featured_in_news: false }],
  );
});

test("news carousel selection matches API advisory ids with different primitive types", () => {
  const advisories = [{ id: "42", featured_in_news: false }];

  assert.deepEqual(
    applyNewsCarouselSelection(advisories, 42, true),
    [{ id: "42", featured_in_news: true }],
  );
});

test("new carousel advisory is merged into UI state immediately with its media", () => {
  assert.deepEqual(
    mergeCreatedAdvisory([], {
      id: 42,
      title: "Road closure",
      featured_in_news: 1,
    }, {
      mediaUrl: "/uploads/road.jpg",
      mediaKind: "photo",
    }),
    [{
      id: 42,
      title: "Road closure",
      featured_in_news: 1,
      media_url: "/uploads/road.jpg",
      media_kind: "photo",
    }],
  );
});

test("featured News carousel previews include only selected advisories with media", () => {
  assert.deepEqual(
    getFeaturedNewsCarouselAdvisories([
      { id: 1, featured_in_news: true, media: { kind: "photo", src: "/road.jpg" } },
      { id: 2, featured_in_news: 1, media: { kind: "gif", src: "/alert.gif" } },
      { id: 3, featured_in_news: true, media_kind: "video", media_url: "/clip.mp4" },
      { id: 4, featured_in_news: false, media: { kind: "photo", src: "/other.jpg" } },
    ]).map((advisory) => advisory.id),
    [1, 2],
  );
});

test("news carousel selector is recognized as a partial advisory update", () => {
  assert.equal(isNewsCarouselOnlyUpdate({ featuredInNews: true }), true);
  assert.equal(isNewsCarouselOnlyUpdate({ featuredInNews: false }), true);
  assert.equal(isNewsCarouselOnlyUpdate({ featuredInNews: true, title: "Road update" }), false);
});

test("news carousel featured count handles API boolean representations", () => {
  assert.equal(
    getNewsCarouselFeaturedCount([
      { featured_in_news: true },
      { featured_in_news: 1 },
      { featured_in_news: "1" },
      { featured_in_news: 0 },
    ]),
    3,
  );
});

test("advisory validation explains which required field is missing", () => {
  assert.equal(validateAdvisoryDraft("  ", "Message"), "Enter an advisory title.");
  assert.equal(validateAdvisoryDraft("Title", "  "), "Enter an advisory message.");
  assert.equal(validateAdvisoryDraft(" Title ", " Message "), null);
});

test("barangay staff audience is always their assigned barangay", () => {
  assert.equal(
    getAdvisoryAudience(
      { role: "barangay_staff", barangay: "Brgy. Central" },
      "All barangays",
    ),
    "Brgy. Central",
  );
});

test("LGU audience follows the selected recipient scope", () => {
  assert.equal(getAdvisoryAudience({ role: "lgu" }, "Brgy. Dawan"), "Brgy. Dawan");
  assert.equal(
    getAdvisoryAudience({ role: "lgu" }, "All barangays"),
    "All barangays",
  );
});

test("news carousel accepts supported media while a slot is available", () => {
  assert.equal(
    validateNewsCarouselFeature({
      featuredInNews: true,
      featuredCount: 4,
      mediaKind: "photo",
      mediaUrl: "https://example.test/road.jpg",
    }),
    null,
  );
});

test("news carousel recognizes MySQL boolean values returned by the API", () => {
  assert.equal(isNewsCarouselFeatured(true), true);
  assert.equal(isNewsCarouselFeatured(1), true);
  assert.equal(isNewsCarouselFeatured("1"), true);
  assert.equal(isNewsCarouselFeatured(0), false);
  assert.equal(isNewsCarouselFeatured("0"), false);
});

test("news carousel rejects selecting more than five advisories", () => {
  assert.equal(
    validateNewsCarouselFeature({
      featuredInNews: true,
      featuredCount: 5,
      mediaKind: "gif",
      mediaUrl: "https://example.test/road.gif",
    }),
    "Only five advisories can appear in the News carousel.",
  );
});

test("news carousel rejects advisories without image or GIF media", () => {
  assert.equal(
    validateNewsCarouselFeature({
      featuredInNews: true,
      featuredCount: 0,
      mediaKind: "video",
      mediaUrl: "https://example.test/road.mp4",
    }),
    "Attach a photo or GIF to feature this advisory in the News carousel.",
  );
});
