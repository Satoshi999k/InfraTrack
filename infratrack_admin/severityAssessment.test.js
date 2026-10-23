import test from "node:test";
import assert from "node:assert/strict";
import {
  assessReportSeverity,
  parseSeverityResponse,
} from "./severityAssessment.js";

test("severity responses include a supported label and concise analysis", () => {
  assert.deepEqual(
    parseSeverityResponse(
      '{"severity":"High","analysis":"The image shows a damaged road edge that may affect traffic."}',
    ),
    {
      severity: "High",
      analysis: "The image shows a damaged road edge that may affect traffic.",
    },
  );
  assert.throws(
    () =>
      parseSeverityResponse(
        '{"severity":"Emergency","analysis":"Urgent."}',
      ),
    /unsupported report severity/,
  );
  assert.throws(() => parseSeverityResponse("not json"), /valid JSON/);
  assert.throws(
    () => parseSeverityResponse('{"severity":"High","analysis":""}'),
    /assessment explanation/,
  );
});

test("severity request uses a compact prompt and no image when absent", async () => {
  let requestBody;
  const assessment = await assessReportSeverity({
    description: "Pothole near the market.",
    category: "Roads",
    env: { GEMINI_API_KEY: "test-key" },
    fetchImpl: async (_url, options) => {
      requestBody = JSON.parse(options.body);
      return Response.json({
        candidates: [{
          content: {
            parts: [{
              text: '{"severity":"Medium","analysis":"The description indicates a repair is needed, with no immediate danger reported."}',
            }],
          },
        }],
      });
    },
  });

  assert.equal(assessment.severity, "Medium");
  assert.match(assessment.analysis, /repair is needed/);
  assert.equal(requestBody.generationConfig.maxOutputTokens, 100);
  assert.equal(requestBody.generationConfig.temperature, 0);
  assert.equal(requestBody.contents[0].parts.length, 1);
  assert.match(requestBody.contents[0].parts[0].text, /Pothole near the market/);
});

test("severity request discovers a supported Gemini model after a 404", async () => {
  const requestedModels = [];
  const assessment = await assessReportSeverity({
    description: "Pothole near the market.",
    category: "Roads",
    env: { GEMINI_API_KEY: "gemini-test" },
    fetchImpl: async (url) => {
      if (url.includes("/v1beta/models?")) {
        return Response.json({
          models: [
            {
              name: "models/gemini-2.5-flash-preview-tts",
              supportedGenerationMethods: ["generateContent"],
            },
            {
              name: "models/gemini-2.5-flash",
              supportedGenerationMethods: ["generateContent"],
            },
          ],
        });
      }
      const model = decodeURIComponent(url.match(/models\/([^:]+)/)[1]);
      requestedModels.push(model);
      if (model === "gemini-2.5-flash-lite") {
        return { ok: false, status: 404 };
      }
      return Response.json({
        candidates: [{
          content: {
            parts: [{
              text: '{"severity":"Medium","analysis":"The report indicates a repair is needed."}',
            }],
          },
        }],
      });
    },
  });

  assert.equal(assessment.severity, "Medium");
  assert.deepEqual(requestedModels, [
    "gemini-2.5-flash-lite",
    "gemini-2.5-flash",
  ]);
});

test("severity request sends only the prepared JPEG frame with the compact prompt", async () => {
  let requestBody;
  let extracted = false;
  const assessment = await assessReportSeverity({
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
        candidates: [{
          content: {
            parts: [{
              text: '{"severity":"High","analysis":"The sampled frame shows a broken road edge."}',
            }],
          },
        }],
      });
    },
  });

  assert.equal(assessment.severity, "High");
  assert.match(assessment.analysis, /broken road edge/);
  assert.equal(extracted, true);
  assert.equal(
    requestBody.contents[0].parts[1].inlineData.data,
    Buffer.from("small jpeg frame").toString("base64"),
  );
  assert.equal(requestBody.contents[0].parts[1].inlineData.mimeType, "image/jpeg");
});

test("severity request discovers an available Groq vision model after a 404", async () => {
  const requestedModels = [];
  const assessment = await assessReportSeverity({
    description: "A damaged road edge.",
    category: "Roads",
    mediaType: "photo",
    mediaBuffer: Buffer.from("small jpeg"),
    env: { GROQ_API_KEY: "groq-test" },
    fetchImpl: async (url, options) => {
      if (url.endsWith("/models")) {
        return Response.json({
          data: [
            { id: "text-only-model", active: true },
            {
              id: "available-vision-model",
              active: true,
              capabilities: { vision: true },
            },
          ],
        });
      }
      const body = JSON.parse(options.body);
      requestedModels.push(body.model);
      if (body.model === "meta-llama/llama-4-scout-17b-16e-instruct") {
        return { ok: false, status: 404 };
      }
      return Response.json({
        choices: [{
          message: {
            content: '{"severity":"High","analysis":"The image shows a damaged road edge."}',
          },
        }],
      });
    },
  });

  assert.equal(assessment.severity, "High");
  assert.deepEqual(requestedModels, [
    "meta-llama/llama-4-scout-17b-16e-instruct",
    "available-vision-model",
  ]);
});

test("severity request falls back to Groq vision when Gemini is unavailable", async () => {
  const requests = [];
  const assessment = await assessReportSeverity({
    description: "A damaged road edge.",
    category: "Roads",
    mediaType: "photo",
    mediaBuffer: Buffer.from("small jpeg"),
    env: {
      GEMINI_API_KEY: "gemini-test",
      GROQ_API_KEY: "groq-test",
    },
    fetchImpl: async (url, options) => {
      requests.push({ url, options });
      if (url.includes("generativelanguage.googleapis.com")) {
        return { ok: false, status: 503 };
      }
      return Response.json({
        choices: [{
          message: {
            content: '{"severity":"High","analysis":"The image shows a damaged road edge."}',
          },
        }],
      });
    },
  });

  assert.equal(assessment.severity, "High");
  assert.match(assessment.analysis, /damaged road edge/);
  assert.equal(requests.length, 2);
  assert.match(requests[1].url, /api\.groq\.com\/openai\/v1\/chat\/completions/);
  const groqBody = JSON.parse(requests[1].options.body);
  assert.equal(groqBody.model, "meta-llama/llama-4-scout-17b-16e-instruct");
  assert.match(
    groqBody.messages[0].content[1].image_url.url,
    /^data:image\/jpeg;base64,/,
  );
});

test("severity request fails explicitly without an AI key or valid model output", async () => {
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
