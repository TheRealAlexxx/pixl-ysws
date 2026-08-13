import axios from "axios";
import type { WebClient } from "@slack/web-api";
import type { AIRequestBody, AIResponse, SlackPostParams } from "./types.js";
import { sanitizeAIOutput } from "./outputFilter.js";

const OPENROUTER_URL = "https://openrouter.ai/api/v1/chat/completions";

export const NO_CREDITS = "__NO_CREDITS__";
export const RATE_LIMITED = "__RATE_LIMITED__";

export class AIError extends Error {
  code: typeof NO_CREDITS | typeof RATE_LIMITED;
  constructor(message: string, code: typeof NO_CREDITS | typeof RATE_LIMITED) {
    super(message);
    this.code = code;
  }
}

function headers(openrouterKey: string) {
  return {
    Authorization: `Bearer ${openrouterKey}`,
    "Content-Type": "application/json",
    "HTTP-Referer": "https://pixorpheus.app",
    "X-Title": "Pixorpheus",
  };
}

/**
 * onDelta(accumulatedText) is called as tokens stream in from OpenRouter.
 * Omit it to get the old buffered behavior (single response once it's all
 * in). Either way the return shape is the same: res.data.choices[0].message.content.
 *
 * Persona chat / roasts / classification model. Gemini 3.1 Flash Lite by
 * default (":nitro" routes to the fastest available provider), cheap and
 * fast for this high-volume bot. Bump to "anthropic/claude-sonnet-4.6" via
 * PIXO_MODEL if you want more punch.
 */
export async function aiCall(
  body: AIRequestBody,
  onDelta?: (accumulated: string) => void,
): Promise<AIResponse> {
  const openrouterKey = process.env.OPENROUTER_API_KEY;
  if (!openrouterKey) throw new AIError("no credits", NO_CREDITS);

  const orBody = {
    ...body,
    model: process.env.PIXO_MODEL || "google/gemini-3.1-flash-lite:nitro",
  };

  if (!onDelta) {
    try {
      const res = await axios.post(OPENROUTER_URL, orBody, {
        headers: headers(openrouterKey),
        timeout: 25000,
      });
      console.log(
        "[openrouter] ok — content:",
        JSON.stringify(res.data?.choices?.[0]?.message?.content)?.slice(0, 80),
      );
      return res as AIResponse;
    } catch (e: any) {
      if (e.response?.status === 429) {
        console.warn("[openrouter] rate limited (429) — staying silent");
        throw new AIError("rate limited", RATE_LIMITED);
      }
      if (e.response?.status === 402) {
        console.error("[openrouter] no credits (402)");
        throw new AIError("no credits", NO_CREDITS);
      }
      console.error(
        "[openrouter] failed (status",
        e.response?.status,
        "):",
        e.response?.data?.error?.message || e.message,
      );
      throw new AIError("transient error", RATE_LIMITED);
    }
  }

  // Streaming path: OpenRouter forwards an SSE stream of
  // "data: {...}\n\n" chunks, each with a choices[0].delta.content
  // fragment, terminated by "data: [DONE]".
  try {
    const res = await axios.post(
      OPENROUTER_URL,
      { ...orBody, stream: true },
      {
        headers: headers(openrouterKey),
        timeout: 45000,
        responseType: "stream",
      },
    );
    let full = "";
    let buf = "";
    await new Promise<void>((resolve, reject) => {
      res.data.on("data", (chunk: Buffer) => {
        buf += chunk.toString("utf8");
        let idx: number;
        while ((idx = buf.indexOf("\n\n")) !== -1) {
          const raw = buf.slice(0, idx).trim();
          buf = buf.slice(idx + 2);
          if (!raw.startsWith("data:")) continue;
          const payload = raw.slice(5).trim();
          if (!payload || payload === "[DONE]") continue;
          try {
            const delta = JSON.parse(payload).choices?.[0]?.delta?.content;
            if (delta) {
              full += delta;
              onDelta(full);
            }
          } catch (e) {
            // ignore malformed chunk, keep streaming
          }
        }
      });
      res.data.on("end", () => resolve());
      res.data.on("error", reject);
    });
    console.log("[openrouter] ok (stream) — content:", JSON.stringify(full).slice(0, 80));
    return { data: { choices: [{ message: { content: full } }] } };
  } catch (e: any) {
    if (e.response?.status === 429) {
      console.warn("[openrouter] rate limited (429) — staying silent");
      throw new AIError("rate limited", RATE_LIMITED);
    }
    if (e.response?.status === 402) {
      console.error("[openrouter] no credits (402)");
      throw new AIError("no credits", NO_CREDITS);
    }
    console.error("[openrouter] stream failed (status", e.response?.status, "):", e.message);
    throw new AIError("transient error", RATE_LIMITED);
  }
}

/** Aliases kept from the original code — same function, different call-site intent. */
export const aiPost = aiCall;
export const aiClassify = aiCall;

/**
 * Applied to the accumulated buffer on every throttled preview update (not
 * just the final text) so a live-streaming reply never flashes something it
 * shouldn't: an in-progress <think> reasoning block, a not-yet-complete
 * REACT: directive line, or (for the SKIP protocol some prompts use) the
 * word "skip" itself.
 */
export function safeDisplayText(raw: string, { stripSkip = false }: { stripSkip?: boolean } = {}): string {
  let t = raw.replace(/<think>[\s\S]*?<\/think>/gi, "");
  const openIdx = t.search(/<think>/i);
  if (openIdx !== -1) t = t.slice(0, openIdx);
  const reactIdx = t.search(/\n\s*REACT\s*:/i);
  if (reactIdx !== -1) t = t.slice(0, reactIdx);
  if (stripSkip) t = t.replace(/^skip\b\s*\n?/i, "");
  return sanitizeAIOutput(t.trim());
}

const STREAM_UPDATE_INTERVAL_MS = 900;

export interface StreamedCallHandle {
  rawContent: string;
  finalize(finalText: string | null | undefined): Promise<void>;
  discard(): Promise<void>;
}

/**
 * Posts a placeholder message immediately, then live-edits it as the model
 * streams in (throttled to respect Slack's chat.update rate limit — Slack
 * will start 429ing well before "every token" territory). Callers get back
 * the raw completion text to run their own leak-detection/cleanup on
 * exactly as they did before streaming existed, then call finalize(text)
 * with the real final text (does the closing edit) or discard() if there's
 * nothing worth keeping (empty reply, detected prompt leak, etc).
 *
 * `format` wraps both the live preview and is available for the caller's
 * own final text too — e.g. roast prefixes every update with "<@user> ".
 * Ephemeral responses (respond()/chat.postEphemeral) can't use this: Slack
 * has no way to edit an ephemeral message after the fact.
 */
export async function streamedAICall(
  client: WebClient,
  postParams: SlackPostParams,
  aiBody: AIRequestBody,
  { format, stripSkip }: { format?: (text: string) => string; stripSkip?: boolean } = {},
): Promise<StreamedCallHandle> {
  const fmt = format || ((t: string) => t);
  let ts: string | undefined;
  let lastUpdate = 0;
  let lastShown: string | null = null;
  let latestFull = "";

  const pushUpdate = (full: string, force = false) => {
    if (!ts) return;
    const display = safeDisplayText(full, { stripSkip });
    if (!display || display === lastShown) return;
    const now = Date.now();
    if (!force && now - lastUpdate < STREAM_UPDATE_INTERVAL_MS) return;
    lastUpdate = now;
    lastShown = display;
    client.chat.update({ channel: postParams.channel, ts: ts!, text: fmt(display) }).catch(() => {});
  };

  // Post the placeholder and start asking the model at the same time — the
  // model can already be generating tokens while we're still waiting on
  // Slack to confirm the placeholder, instead of paying for those two
  // network round-trips back to back. Whatever streamed in during that
  // wait gets flushed immediately once the placeholder lands, bypassing
  // the throttle for that first flush so it doesn't sit on-screen as "…"
  // for up to another 900ms for no reason.
  const placeholderPromise = client.chat
    .postMessage({ ...postParams, text: fmt("…") })
    .then((placeholder) => {
      ts = placeholder.ts;
      if (latestFull) pushUpdate(latestFull, true);
    })
    .catch(() => {
      // no placeholder — fall back to a single non-streamed post in finalize()
    });

  const onDelta = (full: string) => {
    latestFull = full;
    pushUpdate(full);
  };

  let res: AIResponse;
  try {
    res = await aiCall(aiBody, onDelta);
  } catch (e) {
    await placeholderPromise;
    if (ts) client.chat.delete({ channel: postParams.channel, ts }).catch(() => {});
    throw e;
  }
  await placeholderPromise;

  const rawContent = res.data.choices?.[0]?.message?.content || "";
  return {
    rawContent,
    async finalize(finalText) {
      const safeText = finalText ? sanitizeAIOutput(finalText) : finalText;
      if (!ts) {
        if (safeText) await client.chat.postMessage({ ...postParams, text: safeText });
        return;
      }
      if (!safeText) {
        await client.chat.delete({ channel: postParams.channel, ts }).catch(() => {});
        return;
      }
      await client.chat.update({ channel: postParams.channel, ts, text: safeText }).catch(() => {});
    },
    async discard() {
      if (ts) await client.chat.delete({ channel: postParams.channel, ts }).catch(() => {});
    },
  };
}
