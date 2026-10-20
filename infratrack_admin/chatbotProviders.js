const systemInstruction = [
  "You are InfraTrack's helpful resident-support assistant for Mati City, Davao Oriental.",
  "Help users understand how to report infrastructure issues, use the app, read advisories, and follow general reporting steps.",
  "Do not claim to know a user's report status, account data, live city conditions, or current advisories unless that information is included in the conversation.",
  "Never ask for passwords, verification codes, identity-document images, or other sensitive credentials.",
  "For emergencies or immediate danger, tell the user to contact local emergency services and not rely on this chatbot.",
  "Be concise, respectful, and clear. When unsure, say so and direct the user to the appropriate city office.",
].join(" ");

export class ChatProviderError extends Error {
  constructor(
    message,
    {
      status = 502,
      code = "CHAT_PROVIDER_UNAVAILABLE",
      providers = [],
    } = {},
  ) {
    super(message);
    this.name = "ChatProviderError";
    this.status = status;
    this.code = code;
    this.providers = providers;
  }
}

class ChatUpstreamError extends Error {
  constructor(provider, status) {
    super(`${provider} returned HTTP ${status}`);
    this.provider = provider;
    this.status = status;
  }
}

function normalizeMessages(messages) {
  return messages
    .slice(-12)
    .map(({ role, content }) => ({
      role: role === "assistant" ? "assistant" : "user",
      content: String(content).trim().slice(0, 2000),
    }))
    .filter(({ content }) => content.length > 0);
}

async function requestGemini({ apiKey, model, messages, fetchImpl }) {
  const response = await fetchImpl(
    `https://generativelanguage.googleapis.com/v1beta/models/${encodeURIComponent(model)}:generateContent?key=${encodeURIComponent(apiKey)}`,
    {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      signal: AbortSignal.timeout(25_000),
      body: JSON.stringify({
        systemInstruction: { parts: [{ text: systemInstruction }] },
        contents: messages.map(({ role, content }) => ({
          role: role === "assistant" ? "model" : "user",
          parts: [{ text: content }],
        })),
        generationConfig: { maxOutputTokens: 512, temperature: 0.5 },
      }),
    },
  );

  if (!response.ok) throw new ChatUpstreamError("Gemini", response.status);
  const data = await response.json();
  const reply = data.candidates?.[0]?.content?.parts
    ?.map((part) => part.text || "")
    .join("")
    .trim();
  if (!reply) throw new Error("Gemini returned an empty response");
  return reply;
}

async function requestGroqLlama({ apiKey, model, messages, fetchImpl }) {
  const response = await fetchImpl("https://api.groq.com/openai/v1/chat/completions", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${apiKey}`,
      "Content-Type": "application/json",
    },
    signal: AbortSignal.timeout(25_000),
    body: JSON.stringify({
      model,
      messages: [
        { role: "system", content: systemInstruction },
        ...messages,
      ],
      max_tokens: 512,
      temperature: 0.5,
    }),
  });

  if (!response.ok) throw new ChatUpstreamError("Groq", response.status);
  const data = await response.json();
  const reply = data.choices?.[0]?.message?.content?.trim();
  if (!reply) throw new Error("Groq returned an empty response");
  return reply;
}

export async function generateChatReply({
  messages,
  env = process.env,
  fetchImpl = fetch,
}) {
  const normalizedMessages = normalizeMessages(messages);
  if (!normalizedMessages.length) {
    throw new ChatProviderError("A non-empty message is required.", {
      status: 400,
      code: "INVALID_CHAT_MESSAGE",
    });
  }

  const providers = [];
  if (env.GEMINI_API_KEY) {
    providers.push({
      name: "Gemini",
      request: () =>
        requestGemini({
          apiKey: env.GEMINI_API_KEY,
          model: env.GEMINI_MODEL || "gemini-2.5-flash",
          messages: normalizedMessages,
          fetchImpl,
        }),
    });
  }
  if (env.GROQ_API_KEY) {
    providers.push({
      name: "Groq/Llama",
      request: () =>
        requestGroqLlama({
          apiKey: env.GROQ_API_KEY,
          model: env.GROQ_LLAMA_MODEL || "llama-3.3-70b-versatile",
          messages: normalizedMessages,
          fetchImpl,
        }),
    });
  }

  if (!providers.length) {
    throw new ChatProviderError("The AI chatbot has not been configured yet.", {
      status: 503,
      code: "CHAT_NOT_CONFIGURED",
    });
  }

  const failures = [];
  for (const provider of providers) {
    try {
      return await provider.request();
    } catch (error) {
      failures.push(
        error instanceof ChatUpstreamError
          ? { provider: error.provider, status: error.status }
          : { provider: provider.name, status: null },
      );
    }
  }

  throw new ChatProviderError(
    `All configured AI providers failed (${failures.map(({ provider, status }) => `${provider}: ${status == null ? "network or response error" : `HTTP ${status}`}`).join("; ")})`,
    { providers: failures },
  );
}
