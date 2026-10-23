import test from "node:test";
import assert from "node:assert/strict";
import {
  assessReportSeverity,
  parseSeverityResponse,
} from "./severityAssessment.js";

test("severity responses accept only the supported labels", () => {
  assert.equal(parseSeverityResponse('{"severity":"High"}'), "High");
  assert.throws(
    () => parseSeverityResponse('{"severity":"Emergency"}'),
    /unsupported report severity/,
  );
  assert.throws(() => parseSeverityResponse("not json"), /valid JSON/);
});

test("severity request uses a short prompt, low output limit, and no image when absent", async () => {
  let requestBody;
  const severity = await assessReportSeverity({
    description: "Pothole near the market.",
    category: "Roads",
    env: { GEMINI_API_KEY: "test-key" },
    fetchImpl: async (_url, options) => {
      requestBody = JSON.parse(options.body);
      return Response.json({
        candidates: [{ content: { parts: [{ text: '{"severity":"Medium"}' }] } }],
      });
    },
  });

  assert.equal(severity, "Medium");
  assert.equal(requestBody.generationConfig.maxOutputTokens, 24);
  assert.equal(requestBody.generationConfig.temperature, 0);
  assert.equal(requestBody.contents[0].parts.length, 1);
  assert.match(requestBody.contents[0].parts[0].text, /Pothole near the market/);
});

test("severity request sends only the prepared JPEG frame with the compact prompt", async () => {
  let requestBody;
  let extracted = false;
  const severity = await assessReportSeverity({
    description: "A broken road edge.",
    category: "Roads",
    mediaType: "video",
    mediaBuffer: Buffer.from("short video"),
    videoFrameExtractor: async () => {
      extracted = true;
      return Buffer.from("small jpeg frame");
    },
    env: { GEMINI_API_KEY: "test-key" },
    fetchImpl: async (_url, options) => {
      requestBody = JSON.parse(options.body);
      return Response.json({
        candidates: [{ content: { parts: [{ text: '{"severity":"High"}' }] } }],
      });
    },
  });

  assert.equal(severity, "High");
  assert.equal(extracted, true);
  assert.equal(
    requestBody.contents[0].parts[1].inlineData.data,
    Buffer.from("small jpeg frame").toString("base64"),
  );
  assert.equal(requestBody.contents[0].parts[1].inlineData.mimeType, "image/jpeg");
});

test("severity request fails explicitly without a Gemini key or valid model output", async () => {
  await assert.rejects(
    assessReportSeverity({
      description: "Pothole.",
      category: "Roads",
      env: {},
    }),
    { status: 503 },
  );

  await assert.rejects(
    assessReportSeverity({
      description: "Pothole.",
      category: "Roads",
      env: { GEMINI_API_KEY: "test-key" },
      fetchImpl: async () =>
        Response.json({
          candidates: [{ content: { parts: [{ text: '{"severity":"Maybe"}' }] } }],
        }),
    }),
    /unsupported report severity/,
  );
});
