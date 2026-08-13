const express = require("express");
const crypto = require("crypto");

const app = express();
app.use(express.json());

const PORT = process.env.PORT || 4100;
const API_KEY = process.env.EXTERNAL_API_KEY;
const SLACK_BOT_TOKEN = process.env.SLACK_BOT_TOKEN;

const MAX_MESSAGE_LENGTH = 3000;
const GLOBAL_RATE_LIMIT = 60; // requests per minute, total
const PER_USER_RATE_LIMIT = 5; // messages per userId per minute
const RATE_WINDOW_MS = 60 * 1000;
// The per-minute global cap alone still allows sustained abuse over hours
// (rotating the target userId doesn't help an attacker dodge it, but it also
// doesn't stop a long-running campaign against many different real users) —
// this daily ceiling bounds total blast radius if the API key ever leaks.
const DAILY_GLOBAL_LIMIT = Number(process.env.PIXO_DM_DAILY_LIMIT) || 1000;
const DAY_WINDOW_MS = 24 * 60 * 60 * 1000;
const USER_ID_RE = /^[UC][A-Z0-9]{7,}$/;

let globalHits = [];
let dailyHits = [];
const perUserHits = new Map();

function pruneOld(hits, now, windowMs) {
  while (hits.length && now - hits[0] > windowMs) hits.shift();
  return hits;
}

// perUserHits would otherwise grow forever (one entry per distinct userId
// ever messaged) since nothing ever deletes a key once its hits age out.
setInterval(() => {
  const now = Date.now();
  for (const [userId, hits] of perUserHits) {
    if (pruneOld(hits, now, RATE_WINDOW_MS).length === 0) perUserHits.delete(userId);
  }
}, RATE_WINDOW_MS).unref();

function isRateLimited(userId) {
  const now = Date.now();

  pruneOld(globalHits, now, RATE_WINDOW_MS);
  if (globalHits.length >= GLOBAL_RATE_LIMIT) return true;

  pruneOld(dailyHits, now, DAY_WINDOW_MS);
  if (dailyHits.length >= DAILY_GLOBAL_LIMIT) return true;

  const userHits = pruneOld(perUserHits.get(userId) || [], now, RATE_WINDOW_MS);
  if (userHits.length >= PER_USER_RATE_LIMIT) return true;

  globalHits.push(now);
  dailyHits.push(now);
  userHits.push(now);
  perUserHits.set(userId, userHits);
  return false;
}

function safeEqual(a, b) {
  const bufA = Buffer.from(String(a ?? ""));
  const bufB = Buffer.from(String(b ?? ""));
  if (bufA.length !== bufB.length) return false;
  return crypto.timingSafeEqual(bufA, bufB);
}

app.get("/", (_req, res) => res.json({ ok: true, service: "pixo-dm" }));

app.post("/api/external/dm", async (req, res) => {
  if (!API_KEY) return res.status(503).json({ error: "API key not configured" });
  if (!safeEqual(req.headers["x-api-key"], API_KEY))
    return res.status(401).json({ error: "Invalid API key" });

  const { userId, message } = req.body || {};
  if (!userId?.trim() || !message?.trim())
    return res.status(400).json({ error: "Missing userId or message" });

  const target = userId.trim();
  if (!USER_ID_RE.test(target))
    return res.status(400).json({ error: "Invalid userId" });

  if (message.trim().length > MAX_MESSAGE_LENGTH)
    return res.status(400).json({ error: `message exceeds ${MAX_MESSAGE_LENGTH} characters` });

  if (isRateLimited(target))
    return res.status(429).json({ error: "Rate limit exceeded" });

  try {
    const r = await fetch("https://slack.com/api/chat.postMessage", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${SLACK_BOT_TOKEN}`,
        "Content-Type": "application/json; charset=utf-8",
      },
      body: JSON.stringify({ channel: target, text: message.trim() }),
    });
    const json = await r.json();
    if (!json.ok) {
      console.error("[pixo-dm] slack error:", json.error);
      return res.status(502).json({ error: "delivery_failed" });
    }
    res.json({ ok: true });
  } catch (e) {
    console.error("[pixo-dm]", e.message);
    res.status(502).json({ error: "delivery_failed" });
  }
});

app.listen(PORT, () => console.log(`pixo-dm listening on ${PORT}`));
