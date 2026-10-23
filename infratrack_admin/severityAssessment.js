import { spawn } from "node:child_process";
import ffmpegPath from "ffmpeg-static";

export const REPORT_SEVERITIES = ["Low", "Medium", "High", "Critical"];

const MAX_DESCRIPTION_LENGTH = 600;
const MAX_IMAGE_BYTES = 5 * 1024 * 1024;
const MAX_ANALYSIS_LENGTH = 320;
const GEMINI_MODEL = "gemini-2.5-flash-lite";
const GROQ_VISION_MODEL = "meta-llama/llama-4-scout-17b-16e-instruct";

function configuredModel(value, fallback) {
  return String(value ?? "")
    .trim()
    .replace(/^(['"])(.*)\1$/, "$2")
    .trim() || fallback;
}

function severityPrompt(description, category) {
  return `Assess infrastructure report evidence for staff review. Estimate severity as Low, Medium, High, or Critical: Low=minimal risk; Medium=repair needed, limited immediate risk; High=major damage or likely safety/access risk; Critical=immediate serious danger or essential access/service failure. Use only visible/stated evidence, do not invent facts, and state uncertainty when evidence is limited. Return JSON with severity and one concise evidence-based analysis sentence (max 240 characters): {"severity":"Medium","analysis":"..."}.\nCategory: ${String(category ?? "").slice(0, 80)}\nReport: ${String(description).trim().slice(0, MAX_DESCRIPTION_LENGTH)}`;
}

function upstreamError(provider, status) {
  const error = new Error(`${provider} severity request failed (${status}).`);
  error.provider = provider;
  error.status = status === 429 ? 429 : 502;
  error.upstreamStatus = status;
  return error;
}

async function listGeminiModels(apiKey, fetchImpl) {
  const response = await fetchImpl(
    `https://generativelanguage.googleapis.com/v1beta/models?key=${encodeURIComponent(apiKey)}`,
    { signal: AbortSignal.timeout(12_000) },
  );
  if (!response.ok) return [];
  const data = await response.json();
  return (Array.isArray(data.models) ? data.models : [])
    .filter(
      (item) =>
        Array.isArray(item.supportedGenerationMethods) &&
        item.supportedGenerationMethods.includes("generateContent"),
    )
    .map((item) => String(item.name || "").replace(/^models\//i, ""))
    .filter(
      (model) =>
        /^gemini-/i.test(model) &&
        !/(?:tts|text-to-speech|speech|embedding|imagen|veo|audio|transcri|whisper|aqa|live|computer-use|robotics|deep-research)/i.test(
          model,
        ),
    );
}

async function requestGemini({ apiKey, model, prompt, imageBuffer, fetchImpl }) {
  const parts = [{ text: prompt }];
  if (imageBuffer) {
    parts.push({
      inlineData: {
        mimeType: "image/jpeg",
        data: imageBuffer.toString("base64"),
      },
    });
  }
  const response = await fetchImpl(
    `https://generativelanguage.googleapis.com/v1beta/models/${encodeURIComponent(model)}:generateContent?key=${encodeURIComponent(apiKey)}`,
    {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      signal: AbortSignal.timeout(12_000),
      body: JSON.stringify({
        contents: [{ role: "user", parts }],
        generationConfig: {
          maxOutputTokens: 100,
          temperature: 0,
          thinkingConfig: { thinkingBudget: 0 },
          responseMimeType: "application/json",
        },
      }),
    },
  );
  if (!response.ok) throw upstreamError("Gemini", response.status);
  const result = await response.json();
  const generatedText = result.candidates?.[0]?.content?.parts
    ?.map((part) => part.text || "")
    .join("")
    .trim();
  return parseSeverityResponse(generatedText);
}

async function requestGeminiWithFallback(options) {
  try {
    return await requestGemini(options);
  } catch (error) {
    if (error.upstreamStatus !== 404) throw error;
    const availableModels = await listGeminiModels(
      options.apiKey,
      options.fetchImpl,
    );
    const candidates = [GEMINI_MODEL, "gemini-2.5-flash", ...availableModels]
      .filter(
        (model, index, all) =>
          model !== options.model && all.indexOf(model) === index,
      );
    let lastError = error;
    for (const model of candidates) {
      try {
        return await requestGemini({ ...options, model });
      } catch (candidateError) {
        if (candidateError.upstreamStatus !== 404) throw candidateError;
        lastError = candidateError;
      }
    }
    throw lastError;
  }
}

async function requestGroq({ apiKey, model, prompt, imageBuffer, fetchImpl }) {
  const content = [{ type: "text", text: prompt }];
  if (imageBuffer) {
    content.push({
      type: "image_url",
      image_url: {
        url: `data:image/jpeg;base64,${imageBuffer.toString("base64")}`,
      },
    });
  }
  const response = await fetchImpl(
    "https://api.groq.com/openai/v1/chat/completions",
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${apiKey}`,
        "Content-Type": "application/json",
      },
      signal: AbortSignal.timeout(12_000),
      body: JSON.stringify({
        model,
        messages: [{ role: "user", content }],
        max_tokens: 160,
        temperature: 0,
        response_format: { type: "json_object" },
      }),
    },
  );
  if (!response.ok) throw upstreamError("Groq", response.status);
  const result = await response.json();
  return parseSeverityResponse(result.choices?.[0]?.message?.content);
}

function isGroqVisionModel(item) {
  const model = String(item.id || "");
  const capabilities = item.capabilities ?? {};
  const modalities = [
    ...(Array.isArray(item.input_modalities) ? item.input_modalities : []),
    ...(Array.isArray(item.architecture?.input_modalities)
      ? item.architecture.input_modalities
      : []),
  ].map((modality) => String(modality).toLowerCase());
  return (
    capabilities.vision === true ||
    modalities.includes("image") ||
    /(?:vision|scout|maverick|llava|pixtral)/i.test(model)
  );
}

async function listGroqVisionModels(apiKey, fetchImpl) {
  const response = await fetchImpl("https://api.groq.com/openai/v1/models", {
    headers: { Authorization: `Bearer ${apiKey}` },
    signal: AbortSignal.timeout(12_000),
  });
  if (!response.ok) return [];
  const data = await response.json();
  return (Array.isArray(data.data) ? data.data : [])
    .filter((item) => item.active !== false && isGroqVisionModel(item))
    .map((item) => String(item.id || ""))
    .filter(Boolean);
}

async function requestGroqWithFallback(options) {
  try {
    return await requestGroq(options);
  } catch (error) {
    if (error.upstreamStatus !== 404) throw error;
    const availableModels = await listGroqVisionModels(
      options.apiKey,
      options.fetchImpl,
    );
    const candidates = availableModels.filter(
      (model, index, all) =>
        model !== options.model && all.indexOf(model) === index,
    );
    let lastError = error;
    for (const model of candidates) {
      try {
        return await requestGroq({ ...options, model });
      } catch (candidateError) {
        if (candidateError.upstreamStatus !== 404) throw candidateError;
        lastError = candidateError;
      }
    }
    throw lastError;
  }
}

export function parseSeverityResponse(value) {
  const text = String(value ?? "")
    .trim()
    .replace(/^```(?:json)?\s*/i, "")
    .replace(/\s*```$/, "");
  let result;
  try {
    result = JSON.parse(text);
  } catch {
    throw new Error("AI severity response was not valid JSON.");
  }
  if (!REPORT_SEVERITIES.includes(result?.severity)) {
    throw new Error("AI returned an unsupported report severity.");
  }
  const analysis = String(result.analysis ?? "").trim().slice(0, MAX_ANALYSIS_LENGTH);
  if (!analysis) {
    throw new Error("AI did not return an assessment explanation.");
  }
  return { severity: result.severity, analysis };
}

export function extractVideoFrame(videoBuffer, executable = ffmpegPath) {
  return new Promise((resolve, reject) => {
    const args = [
      "-hide_banner",
      "-loglevel",
      "error",
      "-i",
      "pipe:0",
      "-frames:v",
      "1",
      "-vf",
      "scale=512:512:force_original_aspect_ratio=decrease:flags=fast_bilinear",
      "-f",
      "image2pipe",
      "-vcodec",
      "mjpeg",
      "pipe:1",
    ];
    const process = spawn(executable, args, { windowsHide: true });
    const chunks = [];
    let outputBytes = 0;
    let errorOutput = "";
    let settled = false;
    const timeout = setTimeout(() => {
      process.kill();
      fail(new Error("Video severity frame extraction timed out."));
    }, 12_000);

    const cleanup = () => {
      clearTimeout(timeout);
      process.stdin?.destroy();
      process.stdout?.destroy();
      process.stderr?.destroy();
    };
    const fail = (error) => {
      if (settled) return;
      settled = true;
      cleanup();
      reject(error);
    };

    process.on("error", fail);
    process.stdout.on("data", (chunk) => {
      outputBytes += chunk.length;
      if (outputBytes > MAX_IMAGE_BYTES) {
        process.kill();
        fail(new Error("Extracted video frame exceeded the image size limit."));
        return;
      }
      chunks.push(chunk);
    });
    process.stderr.on("data", (chunk) => {
      errorOutput = `${errorOutput}${chunk.toString()}`.slice(-2000);
    });
    process.on("close", (code) => {
      if (settled) return;
      if (code !== 0 || !outputBytes) {
        fail(
          new Error(
            errorOutput.trim() || "Could not extract a frame from the video.",
          ),
        );
        return;
      }
      settled = true;
      cleanup();
      resolve(Buffer.concat(chunks));
    });
    process.stdin.on("error", (error) => {
      if (error.code !== "EPIPE") fail(error);
    });
    process.stdin.end(videoBuffer);
  });
}

export async function assessReportSeverity({
  description,
  category,
  mediaBuffer = null,
  mediaType = null,
  env = process.env,
  fetchImpl = fetch,
  videoFrameExtractor = extractVideoFrame,
}) {
  if (!env.GEMINI_API_KEY && !env.GROQ_API_KEY) {
    const error = new Error("AI severity assessment is not configured.");
    error.status = 503;
    throw error;
  }
  if (!String(description ?? "").trim()) {
    const error = new Error("A report description is required for assessment.");
    error.status = 400;
    throw error;
  }

  let imageBuffer = mediaBuffer;
  if (mediaType === "video" && imageBuffer) {
    imageBuffer = await videoFrameExtractor(imageBuffer);
  }
  if (imageBuffer && imageBuffer.length > MAX_IMAGE_BYTES) {
    const error = new Error("Evidence image must be 5 MB or smaller.");
    error.status = 413;
    throw error;
  }
  if (imageBuffer && !["photo", "video"].includes(mediaType)) {
    const error = new Error("Unsupported severity evidence type.");
    error.status = 400;
    throw error;
  }

  const prompt = severityPrompt(description, category);
  let geminiError;
  if (env.GEMINI_API_KEY) {
    try {
      return await requestGeminiWithFallback({
        apiKey: env.GEMINI_API_KEY,
        model: configuredModel(env.SEVERITY_AI_MODEL, GEMINI_MODEL).replace(
          /^models\//i,
          "",
        ),
        prompt,
        imageBuffer,
        fetchImpl,
      });
    } catch (error) {
      geminiError = error;
    }
  }
  if (env.GROQ_API_KEY) {
    try {
      return await requestGroqWithFallback({
        apiKey: env.GROQ_API_KEY,
        model: configuredModel(
          env.GROQ_SEVERITY_AI_MODEL,
          GROQ_VISION_MODEL,
        ),
        prompt,
        imageBuffer,
        fetchImpl,
      });
    } catch (groqError) {
      if (geminiError) {
        const error = new Error(
          `Severity AI providers failed. ${geminiError.message} ${groqError.message}`,
        );
        error.status = 502;
        throw error;
      }
      throw groqError;
    }
  }
  throw geminiError;
}
