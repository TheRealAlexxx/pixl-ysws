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

let globalHits = [];
const perUserHits = new Map();

function pruneOld(hits, now) {
  while (hits.length && now - hits[0] > RATE_WINDOW_MS) hits.shift();
  return hits;
}

function isRateLimited(userId) {
  const now = Date.now();

  pruneOld(globalHits, now);
  if (globalHits.length >= GLOBAL_RATE_LIMIT) return true;

  const userHits = pruneOld(perUserHits.get(userId) || [], now);
  if (userHits.length >= PER_USER_RATE_LIMIT) return true;

  globalHits.push(now);
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

  if (message.trim().length > MAX_MESSAGE_LENGTH)
    return res.status(400).json({ error: `message exceeds ${MAX_MESSAGE_LENGTH} characters` });

  if (isRateLimited(userId.trim()))
    return res.status(429).json({ error: "Rate limit exceeded" });

  try {
    const r = await fetch("https://slack.com/api/chat.postMessage", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${SLACK_BOT_TOKEN}`,
        "Content-Type": "application/json; charset=utf-8",
      },
      body: JSON.stringify({ channel: userId.trim(), text: message.trim() }),
    });
    const json = await r.json();
    if (!json.ok) return res.status(502).json({ error: json.error || "slack_error" });
    res.json({ ok: true });
  } catch (e) {
    console.error("[pixo-dm]", e.message);
    res.status(502).json({ error: e.message });
  }
});

app.listen(PORT, () => console.log(`pixo-dm listening on ${PORT}`));
