import test from "node:test";
import assert from "node:assert/strict";
import { ChatProviderError, generateChatReply } from "./chatbotProviders.js";

const messages = [{ role: "user", content: "How do I report a pothole?" }];

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
