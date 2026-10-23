import { spawn } from "node:child_process";
import ffmpegPath from "ffmpeg-static";

export const REPORT_SEVERITIES = ["Low", "Medium", "High", "Critical"];

const MAX_DESCRIPTION_LENGTH = 600;
const MAX_IMAGE_BYTES = 5 * 1024 * 1024;

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
  return result.severity;
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
  if (!env.GEMINI_API_KEY) {
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

  const model = String(env.SEVERITY_AI_MODEL || "gemini-2.5-flash-lite")
    .trim()
    .replace(/^models\//i, "");
  const parts = [
    {
      text: `Classify infrastructure damage severity as exactly Low, Medium, High, or Critical. Use only report evidence. Low: minor, non-urgent defect. Medium: repair needed, limited immediate risk. High: major damage or likely safety/access risk. Critical: immediate serious danger or essential access/service failure. If uncertain choose Medium. Return only JSON: {"severity":"Medium"}.\nCategory: ${String(category ?? "").slice(0, 80)}\nReport: ${String(description).trim().slice(0, MAX_DESCRIPTION_LENGTH)}`,
    },
  ];
  if (imageBuffer) {
    parts.push({
      inlineData: {
        mimeType: "image/jpeg",
        data: imageBuffer.toString("base64"),
      },
    });
  }

  const response = await fetchImpl(
    `https://generativelanguage.googleapis.com/v1beta/models/${encodeURIComponent(model)}:generateContent?key=${encodeURIComponent(env.GEMINI_API_KEY)}`,
    {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      signal: AbortSignal.timeout(12_000),
      body: JSON.stringify({
        contents: [{ role: "user", parts }],
        generationConfig: {
          maxOutputTokens: 24,
          temperature: 0,
          thinkingConfig: { thinkingBudget: 0 },
          responseMimeType: "application/json",
        },
      }),
    },
  );
  if (!response.ok) {
    const error = new Error(`Gemini severity request failed (${response.status}).`);
    error.status = response.status === 429 ? 429 : 502;
    throw error;
  }
  const result = await response.json();
  const generatedText = result.candidates?.[0]?.content?.parts
    ?.map((part) => part.text || "")
    .join("")
    .trim();
  return parseSeverityResponse(generatedText);
}
