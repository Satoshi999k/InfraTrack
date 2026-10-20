import test from "node:test";
import assert from "node:assert/strict";
import {
  ChatProviderError,
  generateChatReply,
  normalizeChatRequestMessages,
} from "./chatbotProviders.js";

const messages = [{ role: "user", content: "How do I report a pothole?" }];

test("keeps chat history within message and assistant-context limits", () => {
  const history = [
    { role: "user", content: "Old question" },
    ...Array.from({ length: 12 }, (_, index) => ({
      role: index % 2 === 0 ? "assistant" : "user",
      content: index % 2 === 0 ? "A".repeat(1800) : `Question ${index}`,
    })),
  ];

  const normalized = normalizeChatRequestMessages(history);

  assert.equal(normalized.length, 12);
  assert.ok(normalized.every((message) => message.content.length <= 1200));
  assert.equal(normalized.at(-1).content, "Question 11");
});

test("rejects oversized user messages but safely truncates assistant context", () => {
  assert.deepEqual(
    normalizeChatRequestMessages([
      { role: "assistant", content: "A".repeat(3000) },
      { role: "user", content: "Next question" },
    ]),
    [
      { role: "assistant", content: "A".repeat(1200) },
      { role: "user", content: "Next question" },
    ],
  );
  assert.equal(
    normalizeChatRequestMessages([
      { role: "user", content: "U".repeat(2001) },
    ]),
    null,
  );
});

test("uses Gemini as the primary chatbot provider", async () => {
  const requests = [];
  const reply = await generateChatReply({
    messages,
    env: { GEMINI_API_KEY: "gemini-test", GROQ_API_KEY: "groq-test" },
    fetchImpl: async (url, options) => {
      requests.push({ url, options });
      return {
        ok: true,
        json: async () => ({
          candidates: [{ content: { parts: [{ text: "Use Report an issue." }] } }],
        }),
      };
    },
  });

  assert.equal(reply, "Use Report an issue.");
  assert.equal(requests.length, 1);
  assert.match(requests[0].url, /generativelanguage\.googleapis\.com/);
});

test("normalizes the Gemini display name to its API model ID", async () => {
  let requestUrl;
  await generateChatReply({
    messages,
    env: { GEMINI_API_KEY: "gemini-test", GEMINI_MODEL: '"Gemini 2.5 Flash"' },
    fetchImpl: async (url) => {
      requestUrl = url;
      return {
        ok: true,
        json: async () => ({
          candidates: [{ content: { parts: [{ text: "Hello." }] } }],
        }),
      };
    },
  });

  assert.match(requestUrl, /models\/gemini-2\.5-flash:generateContent/);
});

test("replaces an unsupported Gemma chat override with Gemini Flash", async () => {
  let requestUrl;
  await generateChatReply({
    messages,
    env: { GEMINI_API_KEY: "gemini-test", GEMINI_MODEL: "gemma-4-26b-a4b-it" },
    fetchImpl: async (url) => {
      requestUrl = url;
      return {
        ok: true,
        json: async () => ({
          candidates: [{ content: { parts: [{ text: "Hello." }] } }],
        }),
      };
    },
  });

  assert.match(requestUrl, /models\/gemini-2\.5-flash:generateContent/);
});

test("discovers an available Gemini model after a configured model returns 404", async () => {
  const requests = [];
  const reply = await generateChatReply({
    messages,
    env: { GEMINI_API_KEY: "gemini-test", GEMINI_MODEL: "retired-model" },
    fetchImpl: async (url, options) => {
      requests.push({ url, options });
      if (url.includes("/v1beta/models?")) {
        return {
          ok: true,
          json: async () => ({
            models: [
              {
                name: "models/gemini-2.5-flash-preview-tts",
                supportedGenerationMethods: ["generateContent"],
              },
              {
                name: "models/gemma-4-26b-a4b-it",
                supportedGenerationMethods: ["generateContent"],
              },
              {
                name: "models/gemini-2.5-flash-lite",
                supportedGenerationMethods: ["generateContent"],
              },
            ],
          }),
        };
      }
      if (url.includes("models/gemini-2.5-flash-preview-tts:generateContent")) {
        return { ok: false, status: 400 };
      }
      if (url.includes("models/gemma-4-26b-a4b-it:generateContent")) {
        return { ok: false, status: 400 };
      }
      if (url.includes("models/gemini-2.5-flash-lite:generateContent")) {
        return {
          ok: true,
          json: async () => ({
            candidates: [{ content: { parts: [{ text: "Try the app report form." }] } }],
          }),
        };
      }
      return { ok: false, status: 404 };
    },
  });

  assert.equal(reply, "Try the app report form.");
  assert.ok(
    requests.some(({ url }) =>
      url.includes("models/gemini-2.5-flash-lite:generateContent"),
    ),
  );
  assert.ok(
    !requests.some(({ url }) =>
      url.includes("models/gemini-2.5-flash-preview-tts:generateContent"),
    ),
  );
  assert.ok(
    !requests.some(({ url }) =>
      url.includes("models/gemma-4-26b-a4b-it:generateContent"),
    ),
  );
});

test("falls back to a Llama model on Groq when Gemini is unavailable", async () => {
  const requests = [];
  const reply = await generateChatReply({
    messages,
    env: { GEMINI_API_KEY: "gemini-test", GROQ_API_KEY: "groq-test" },
    fetchImpl: async (url, options) => {
      requests.push({ url, options });
      if (requests.length === 1) return { ok: false, status: 429 };
      return {
        ok: true,
        json: async () => ({
          choices: [{ message: { content: "Select Report an issue in the app." } }],
        }),
      };
    },
  });

  assert.equal(reply, "Select Report an issue in the app.");
  assert.equal(requests.length, 2);
  assert.match(requests[1].url, /api\.groq\.com/);
  assert.equal(
    JSON.parse(requests[1].options.body).model,
    "llama-3.3-70b-versatile",
  );
});

test("normalizes the Groq display name to its API model ID", async () => {
  let requestBody;
  await generateChatReply({
    messages,
    env: {
      GROQ_API_KEY: "groq-test",
      GROQ_LLAMA_MODEL: "Llama 3.3 70B Enterprise",
    },
    fetchImpl: async (_url, options) => {
      requestBody = JSON.parse(options.body);
      return {
        ok: true,
        json: async () => ({
          choices: [{ message: { content: "Hello." } }],
        }),
      };
    },
  });

  assert.equal(requestBody.model, "llama-3.3-70b-versatile");
});

test("maps the retired Groq 3.1 model override to the documented Llama chat model", async () => {
  let requestBody;
  await generateChatReply({
    messages,
    env: {
      GROQ_API_KEY: "groq-test",
      GROQ_LLAMA_MODEL: "llama-3.1-8b-instant",
    },
    fetchImpl: async (_url, options) => {
      requestBody = JSON.parse(options.body);
      return {
        ok: true,
        json: async () => ({
          choices: [{ message: { content: "Hello." } }],
        }),
      };
    },
  });

  assert.equal(requestBody.model, "llama-3.3-70b-versatile");
});

test("discovers an available Groq model after configured models return 404", async () => {
  const requests = [];
  const reply = await generateChatReply({
    messages,
    env: { GROQ_API_KEY: "groq-test", GROQ_LLAMA_MODEL: "retired-model" },
    fetchImpl: async (url, options) => {
      requests.push({ url, options });
      if (url.endsWith("/models")) {
        return {
          ok: true,
          json: async () => ({
            data: [
              { id: "meta-llama/llama-prompt-guard-2-86m", active: true },
              { id: "llama-3.1-8b-instant", active: true },
              { id: "llama-custom-model", active: true },
            ],
          }),
        };
      }
      const model = JSON.parse(options.body).model;
      if (model.includes("prompt-guard") || model.startsWith("llama-3.1")) {
        return { ok: false, status: 400 };
      }
      if (model === "llama-custom-model") {
        return {
          ok: true,
          json: async () => ({
            choices: [{ message: { content: "Use the report form in InfraTrack." } }],
          }),
        };
      }
      return { ok: false, status: 404 };
    },
  });

  assert.equal(reply, "Use the report form in InfraTrack.");
  const discoveryRequest = requests.find(({ url }) => url.endsWith("/models"));
  assert.equal(
    discoveryRequest.options.headers.Authorization,
    "Bearer groq-test",
  );
  assert.ok(
    requests.some(
      ({ options }) =>
        options.body &&
        JSON.parse(options.body).model === "llama-custom-model",
    ),
  );
  assert.ok(
    !requests.some(
      ({ options }) =>
        options.body &&
        JSON.parse(options.body).model.includes("prompt-guard"),
    ),
  );
  assert.ok(
    !requests.some(
      ({ options }) =>
        options.body &&
        JSON.parse(options.body).model.startsWith("llama-3.1"),
    ),
  );
});

test("reports an explicit configuration error when no provider key is set", async () => {
  await assert.rejects(
    generateChatReply({ messages, env: {}, fetchImpl: async () => assert.fail() }),
    (error) =>
      error instanceof ChatProviderError &&
      error.status === 503 &&
      error.code === "CHAT_NOT_CONFIGURED",
  );
});

test("does not hide failure when every configured provider is unavailable", async () => {
  await assert.rejects(
    generateChatReply({
      messages,
      env: { GEMINI_API_KEY: "gemini-test", GROQ_API_KEY: "groq-test" },
      fetchImpl: async () => ({ ok: false, status: 503 }),
    }),
    (error) =>
      error instanceof ChatProviderError &&
      error.status === 502 &&
      error.message.includes("Gemini: HTTP 503") &&
      error.message.includes("Groq: HTTP 503") &&
      error.providers.length === 2,
  );
});

test("rejects empty chat messages before calling a provider", async () => {
  await assert.rejects(
    generateChatReply({
      messages: [{ role: "user", content: "  " }],
      env: { GEMINI_API_KEY: "gemini-test" },
      fetchImpl: async () => assert.fail(),
    }),
    (error) => error instanceof ChatProviderError && error.status === 400,
  );
});
