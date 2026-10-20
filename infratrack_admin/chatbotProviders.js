const systemInstruction = [
  "You are InfraTrack's helpful resident-support assistant for Mati City, Davao Oriental.",
  "Help users understand how to report infrastructure issues, use the app, read advisories, and follow general reporting steps.",
  "Do not claim to know a user's report status, account data, live city conditions, or current advisories unless that information is included in the conversation.",
  "Never ask for passwords, verification codes, identity-document images, or other sensitive credentials.",
  "For emergencies or immediate danger, tell the user to contact local emergency services and not rely on this chatbot.",
  "Give only the final answer. Never show internal reasoning, analysis, drafts, monologues, or multiple candidate answers.",
  "Be concise, respectful, and clear. Answer in at most 3 short sentences. When unsure, say so and direct the user to the appropriate city office.",
].join(" ");

export function normalizeChatRequestMessages(messages) {
  if (!Array.isArray(messages) || messages.length === 0) return null;
  const recentMessages = messages.slice(-12);
  if (
    recentMessages.some(
      (message) =>
        !message ||
        !["user", "assistant"].includes(message.role) ||
        typeof message.content !== "string" ||
        !message.content.trim() ||
        (message.role === "user" && message.content.length > 2000),
    ) ||
    !recentMessages.some((message) => message.role === "user")
  ) {
    return null;
  }
  return recentMessages.map(({ role, content }) => ({
    role,
    content: content.trim().slice(0, role === "assistant" ? 1200 : 2000),
  }));
}

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
  const normalized = model.toLowerCase().replace(/\s+/g, "-");
  if (
    normalized === "gemini-2.5-flash" ||
    normalized === "gemini-2.5-flash-lite"
  ) {
    return normalized;
  }
  return "gemini-2.5-flash";
}

function groqModelId(value) {
  const model = configuredModel(value, "llama-3.3-70b-versatile");
  const normalized = model.toLowerCase().replace(/\s+/g, "-");
  if (normalized.includes("llama-3.3-70b")) {
    return "llama-3.3-70b-versatile";
  }
  if (
    normalized === "llama-3.1-8b-instant" ||
    normalized === "meta-llama/llama-3.1-8b-instant"
  ) {
    return "llama-3.3-70b-versatile";
  }
  return isGroqChatModel(model) ? model : "llama-3.3-70b-versatile";
}

function isGeminiChatModel(model) {
  return !/(?:tts|text-to-speech|speech|embedding|imagen|veo|audio|transcri|whisper|aqa|live|computer-use|robotics|deep-research)/i.test(
    model,
  );
}

function isGroqChatModel(model) {
  return (
    model.toLowerCase().includes("llama") &&
    !/(?:3\.1|prompt.?guard|guard|safety|whisper|speech|audio|embedding|vision)/i.test(
      model,
    )
  );
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
        generationConfig: {
          maxOutputTokens: 256,
          temperature: 0.5,
          thinkingConfig: { thinkingBudget: 0 },
        },
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
    .filter(
      (model) =>
        model &&
        model.toLowerCase().startsWith("gemini-") &&
        isGeminiChatModel(model),
    );
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
      max_tokens: 256,
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
    .filter(isGroqChatModel);
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
