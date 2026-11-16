import test from "node:test";
import assert from "node:assert/strict";
import { getIssueMediaPreview } from "./issuePreview.js";

test("video reports use their poster thumbnail instead of the video URL", () => {
  assert.deepEqual(
    getIssueMediaPreview({
      media_kind: "video",
      media_url: "https://media.example/report.mp4",
      media_thumbnail_url: "https://media.example/report-poster.jpg",
    }),
    {
      isVideo: true,
      thumbnailUrl: "https://media.example/report-poster.jpg",
    },
  );
});

test("video URLs without a poster have no image preview", () => {
  assert.deepEqual(
    getIssueMediaPreview({
      media_url: "https://media.example/report.mp4",
    }),
    { isVideo: true, thumbnailUrl: null },
  );
});

test("photo reports continue to use their media URL as the preview", () => {
  assert.deepEqual(
    getIssueMediaPreview({
      media_kind: "photo",
      media_url: "https://media.example/report.jpg",
    }),
    {
      isVideo: false,
      thumbnailUrl: "https://media.example/report.jpg",
    },
  );
});
