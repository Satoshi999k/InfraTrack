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
  constructor(provider, status, model) {
    super(`${provider} returned HTTP ${status}`);
    this.provider = provider;
    this.status = status;
    this.model = model;
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

function configuredModel(value, fallback) {
  return String(value ?? "")
    .trim()
    .replace(/^(['"])(.*)\1$/, "$2")
    .trim() || fallback;
}

function geminiModelId(value) {
  const model = configuredModel(value, "gemini-2.5-flash").replace(
    /^models\//i,
    "",
  );
  return model.toLowerCase().replace(/\s+/g, "-") === "gemini-2.5-flash"
    ? "gemini-2.5-flash"
    : model;
}

function groqModelId(value) {
  const model = configuredModel(value, "llama-3.3-70b-versatile");
  const normalized = model.toLowerCase().replace(/\s+/g, "-");
  if (
    [
      "llama-3.3-70b",
      "llama-3.3-70b-enterprise",
      "llama-3.3-70b-versatile",
    ].includes(normalized)
  ) {
    return "llama-3.3-70b-versatile";
  }
  return model;
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

  if (!response.ok) {
    throw new ChatUpstreamError("Gemini", response.status, model);
  }
  const data = await response.json();
  const reply = data.candidates?.[0]?.content?.parts
    ?.map((part) => part.text || "")
    .join("")
    .trim();
  if (!reply) throw new Error("Gemini returned an empty response");
  return reply;
}

async function listGeminiModels(apiKey, fetchImpl) {
  const response = await fetchImpl(
    `https://generativelanguage.googleapis.com/v1beta/models?key=${encodeURIComponent(apiKey)}`,
    { signal: AbortSignal.timeout(15_000) },
  );
  if (!response.ok) return [];
  const data = await response.json();
  return (Array.isArray(data.models) ? data.models : [])
    .filter((item) =>
      Array.isArray(item.supportedGenerationMethods)
        ? item.supportedGenerationMethods.includes("generateContent")
        : false,
    )
    .map((item) => String(item.name || "").replace(/^models\//, ""))
    .filter(Boolean);
}

async function requestGeminiWithFallback(options) {
  try {
    return await requestGemini(options);
  } catch (error) {
    if (!(error instanceof ChatUpstreamError) || error.status !== 404) {
      throw error;
    }
    const availableModels = await listGeminiModels(
      options.apiKey,
      options.fetchImpl,
    );
    const candidates = [
      options.model,
      "gemini-2.5-flash",
      "gemini-2.5-flash-lite",
      ...availableModels,
    ].filter((model, index, all) => model && all.indexOf(model) === index);
    let lastError = error;
    for (const model of candidates.slice(1)) {
      try {
        return await requestGemini({ ...options, model });
      } catch (candidateError) {
        if (
          !(candidateError instanceof ChatUpstreamError) ||
          candidateError.status !== 404
        ) {
          throw candidateError;
        }
        lastError = candidateError;
      }
    }
    throw lastError;
  }
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

  if (!response.ok) {
    throw new ChatUpstreamError("Groq", response.status, model);
  }
  const data = await response.json();
  const reply = data.choices?.[0]?.message?.content?.trim();
  if (!reply) throw new Error("Groq returned an empty response");
  return reply;
}

async function listGroqModels(apiKey, fetchImpl) {
  const response = await fetchImpl("https://api.groq.com/openai/v1/models", {
    headers: { Authorization: `Bearer ${apiKey}` },
    signal: AbortSignal.timeout(15_000),
  });
  if (!response.ok) return [];
  const data = await response.json();
  return (Array.isArray(data.data) ? data.data : [])
    .filter((item) => item.active !== false)
    .map((item) => String(item.id || ""))
    .filter((id) => id.toLowerCase().includes("llama"));
}

async function requestGroqWithFallback(options) {
  try {
    return await requestGroqLlama(options);
  } catch (error) {
    if (!(error instanceof ChatUpstreamError) || error.status !== 404) {
      throw error;
    }
    const availableModels = await listGroqModels(
      options.apiKey,
      options.fetchImpl,
    );
    const candidates = [
      options.model,
      "llama-3.3-70b-versatile",
      "llama-3.1-8b-instant",
      ...availableModels,
    ].filter((model, index, all) => model && all.indexOf(model) === index);
    let lastError = error;
    for (const model of candidates.slice(1)) {
      try {
        return await requestGroqLlama({ ...options, model });
      } catch (candidateError) {
        if (
          !(candidateError instanceof ChatUpstreamError) ||
          candidateError.status !== 404
        ) {
          throw candidateError;
        }
        lastError = candidateError;
      }
    }
    throw lastError;
  }
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
        requestGeminiWithFallback({
          apiKey: env.GEMINI_API_KEY,
          model: geminiModelId(env.GEMINI_MODEL),
          messages: normalizedMessages,
          fetchImpl,
        }),
    });
  }
  if (env.GROQ_API_KEY) {
    providers.push({
      name: "Groq/Llama",
      request: () =>
        requestGroqWithFallback({
          apiKey: env.GROQ_API_KEY,
          model: groqModelId(env.GROQ_LLAMA_MODEL),
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
          ? {
              provider: error.provider,
              status: error.status,
              model: error.model,
            }
          : { provider: provider.name, status: null, model: null },
      );
    }
  }

  throw new ChatProviderError(
    `All configured AI providers failed (${failures.map(({ provider, status }) => `${provider}: ${status == null ? "network or response error" : `HTTP ${status}`}`).join("; ")})`,
    { providers: failures },
  );
}
