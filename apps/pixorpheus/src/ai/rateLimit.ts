// Per-user sliding-window limiter shared by every AI (OpenRouter) and search
// (Brave) call site — slash commands and the in-thread chat pipeline alike —
// so one person spamming can't burn through the workspace's shared credits.

const buckets = new Map<string, number[]>();
let callsSinceSweep = 0;

export interface RateLimitOptions {
  max: number;
  windowMs: number;
}

// 8 AI-triggering actions per minute is generous for a real conversation
// (each slash command / thread reply is one hit) but stops a tight loop of
// spam commands or repeated pings from draining credits.
export const DEFAULT_AI_RATE_LIMIT: RateLimitOptions = { max: 8, windowMs: 60_000 };

export const AI_RATE_LIMIT_MESSAGE = "chill for a sec, you're spamming me 💀 try again in a bit";

export function checkAiRateLimit(userId: string, opts: RateLimitOptions = DEFAULT_AI_RATE_LIMIT): boolean {
  const now = Date.now();
  const arr = (buckets.get(userId) ?? []).filter((t) => now - t < opts.windowMs);

  if (arr.length >= opts.max) {
    if (arr.length) buckets.set(userId, arr);
    else buckets.delete(userId);
    return false;
  }

  arr.push(now);
  buckets.set(userId, arr);

  // Occasionally sweep every bucket, not just this user's, so entries for
  // people who've gone quiet get dropped instead of sitting in memory for
  // the rest of the process lifetime.
  if (++callsSinceSweep >= 200) {
    callsSinceSweep = 0;
    for (const [uid, times] of buckets) {
      if (!times.some((t) => now - t < opts.windowMs)) buckets.delete(uid);
    }
  }

  return true;
}
