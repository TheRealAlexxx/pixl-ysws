import { randomInt } from "crypto";
import { Router } from "express";
import { verifySessionToken } from "../auth/session.js";
import { supabase } from "../db/client.js";
import { addNotification } from "./notifications.js";

const router = Router();

const CODE_ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"; // no 0/O/1/I, easy to read aloud
const CODE_LENGTH = 6;

// Keep in sync with REFERRAL_BOOST_SHIP_CAP in apps/dashboard/lib/db.ts , the
// boost only ever applies to this many of the referred player's ships.
const BOOST_SHIP_CAP = 1;

// A code can only be applied while the *referred* account is still new. Without
// this, two existing players who've been shipping for months could "refer"
// each other after the fact and collect the payout with zero real user
// acquisition , worse, veteran players are a safer bet for hitting a big
// reward tier than an actual newcomer, which inverts the whole incentive.
const REFERRAL_WINDOW_DAYS = 2;

function randomCode(): string {
  let out = "";
  for (let i = 0; i < CODE_LENGTH; i++) out += CODE_ALPHABET[randomInt(CODE_ALPHABET.length)];
  return out;
}

// Assign a player their referral code the first time it's asked for. Retries
// on the rare collision (unique constraint on users.referral_code).
async function ensureReferralCode(userId: string): Promise<string> {
  const { data: existing } = await supabase
    .from("users")
    .select("referral_code")
    .eq("id", userId)
    .single();
  if (existing?.referral_code) return existing.referral_code as string;

  for (let attempt = 0; attempt < 5; attempt++) {
    const code = randomCode();
    const { data, error } = await supabase
      .from("users")
      .update({ referral_code: code })
      .eq("id", userId)
      .is("referral_code", null)
      .select("referral_code")
      .single();
    if (!error && data) return code;
  }
  // Someone else claimed every code we tried, or a race set it concurrently , read back whatever won.
  const { data: settled } = await supabase
    .from("users")
    .select("referral_code")
    .eq("id", userId)
    .single();
  return (settled?.referral_code as string) ?? randomCode();
}

router.get("/api/referral/me", async (req, res) => {
  const token = typeof req.query.token === "string" ? req.query.token : "";
  const session = token ? verifySessionToken(token) : null;
  if (!session) return res.status(401).json({ ok: false });

  const code = await ensureReferralCode(session.userId);

  const [{ data: asReferred }, { data: referredByMe }, { data: me }] = await Promise.all([
    supabase
      .from("referrals")
      .select("boosted_ships, rewarded_at")
      .eq("referred_id", session.userId)
      .maybeSingle(),
    supabase
      .from("referrals")
      .select("rewarded_at, reward_tier, reward_pixels")
      .eq("referrer_id", session.userId),
    supabase.from("users").select("created_at").eq("id", session.userId).single(),
  ]);

  const referrals = referredByMe ?? [];
  const rewarded = referrals.filter((r) => r.rewarded_at);
  const accountAgeMs = me?.created_at ? Date.now() - new Date(me.created_at as string).getTime() : Infinity;
  const canApply = !asReferred && accountAgeMs <= REFERRAL_WINDOW_DAYS * 86400_000;

  res.json({
    ok: true,
    code,
    canApply,
    referralWindowDays: REFERRAL_WINDOW_DAYS,
    boost: asReferred
      ? {
          shipsUsed: asReferred.boosted_ships,
          shipsRemaining: Math.max(0, BOOST_SHIP_CAP - asReferred.boosted_ships),
        }
      : null,
    referrals: {
      total: referrals.length,
      rewarded: rewarded.length,
      pixelsEarned: rewarded.reduce((s, r) => s + (Number(r.reward_pixels) || 0), 0),
    },
  });
});

router.post("/api/referral/apply", async (req, res) => {
  const token = typeof req.query.token === "string" ? req.query.token : "";
  const session = token ? verifySessionToken(token) : null;
  if (!session) return res.status(401).json({ ok: false });

  const code = typeof req.body?.code === "string" ? req.body.code.trim().toUpperCase() : "";
  if (!code) return res.status(400).json({ ok: false, reason: "Enter a referral code." });

  const { data: alreadyReferred } = await supabase
    .from("referrals")
    .select("id")
    .eq("referred_id", session.userId)
    .maybeSingle();
  if (alreadyReferred)
    return res.status(400).json({ ok: false, reason: "You've already used a referral code." });

  const { data: me } = await supabase
    .from("users")
    .select("created_at")
    .eq("id", session.userId)
    .single();
  const accountAgeMs = me?.created_at ? Date.now() - new Date(me.created_at as string).getTime() : Infinity;
  if (accountAgeMs > REFERRAL_WINDOW_DAYS * 86400_000)
    return res.status(400).json({
      ok: false,
      reason: `Referral codes can only be applied within your first ${REFERRAL_WINDOW_DAYS} days on Pixl.`,
    });

  const { data: referrer } = await supabase
    .from("users")
    .select("id, display_name")
    .eq("referral_code", code)
    .maybeSingle();
  if (!referrer)
    return res.status(404).json({ ok: false, reason: "That referral code doesn't exist." });
  if (referrer.id === session.userId)
    return res.status(400).json({ ok: false, reason: "You can't refer yourself." });

  const { error } = await supabase
    .from("referrals")
    .insert({ referrer_id: referrer.id, referred_id: session.userId });
  if (error) {
    console.error("[referral] apply failed", error);
    return res.status(500).json({ ok: false, reason: "Couldn't apply that code, try again." });
  }

  await addNotification(
    referrer.id as string,
    "Referral accepted",
    "Someone joined Pixl with your referral code. You'll get paid out when they ship their first qualifying project.",
  );
  res.json({ ok: true, referrerName: referrer.display_name });
});

export default router;
