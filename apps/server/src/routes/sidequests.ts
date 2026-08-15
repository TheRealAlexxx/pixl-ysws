import { Router } from "express";
import { verifySessionToken } from "../auth/session.js";
import { supabase } from "../db/client.js";

const router = Router();

// Quest log: every active sidequest, flagged with whether this player has
// unlocked it (NPCs grant unlocks; that wiring lands later).
router.get("/api/sidequests", async (req, res) => {
  const token = typeof req.query.token === "string" ? req.query.token : "";
  const session = token ? verifySessionToken(token) : null;
  if (!session) return res.status(401).json({ ok: false });

  const [{ data: quests, error }, { data: unlocks }, { data: projects }] =
    await Promise.all([
      supabase
        .from("sidequests")
        // min_hours rides along so the projects page can show progress toward
        // the same gate the ship route enforces.
        .select("id, name, region, npc, description, reward, starter, min_hours")
        .eq("active", true)
        .order("position", { ascending: true })
        .order("id", { ascending: true }),
      supabase
        .from("sidequest_unlocks")
        .select("sidequest_id")
        .eq("user_id", session.userId),
      // A Trial counts as completed once the player has a project linked to it
      // that's reached (or passed) review.
      supabase
        .from("projects")
        .select("sidequest_id")
        .eq("user_id", session.userId)
        .not("sidequest_id", "is", null)
        .in("status", ["shipped", "second_review", "approved"]),
    ]);
  if (error) return res.json({ ok: true, quests: [] });
  const unlocked = new Set((unlocks ?? []).map((u) => u.sidequest_id as number));
  const completed = new Set(
    (projects ?? []).map((p) => p.sidequest_id as number),
  );
  res.json({
    ok: true,
    quests: (quests ?? []).map((q) => ({
      ...q,
      unlocked: unlocked.has(q.id as number),
      completed: completed.has(q.id as number),
    })),
  });
});

// Accept a Trial — the "I'll take it" from an NPC. Idempotent: the unique
// (sidequest_id, user_id) on sidequest_unlocks means re-accepting is a no-op.
// Only active Trials can be accepted.
router.post("/api/sidequests/:id/accept", async (req, res) => {
  const token = typeof req.query.token === "string" ? req.query.token : "";
  const session = token ? verifySessionToken(token) : null;
  if (!session) return res.status(401).json({ ok: false });

  const id = Number(req.params.id);
  if (!Number.isFinite(id)) return res.status(400).json({ ok: false });

  const { data: quest } = await supabase
    .from("sidequests")
    .select("id")
    .eq("id", id)
    .eq("active", true)
    .maybeSingle();
  if (!quest) return res.status(404).json({ ok: false, error: "not_found" });

  const { error } = await supabase
    .from("sidequest_unlocks")
    .upsert(
      { sidequest_id: id, user_id: session.userId },
      { onConflict: "sidequest_id,user_id", ignoreDuplicates: true },
    );
  if (error) {
    console.error("[sidequests] accept failed", error.message);
    return res.status(500).json({ ok: false });
  }
  res.json({ ok: true });
});

// Pixo's first-Trial recommendation. Picks one active *starter* Trial whose
// difficulty best matches the player's coding experience — but always returns
// the full starter list too, so the Trial Board can offer "browse all" and
// never forces the pick. Requires drizzle/0050 (difficulty/starter columns).
const EXPERIENCE_DIFFICULTY: Record<string, number> = {
  beginner: 1,
  intermediate: 2,
  advanced: 3,
};

router.get("/api/sidequests/recommended", async (req, res) => {
  const token = typeof req.query.token === "string" ? req.query.token : "";
  const session = token ? verifySessionToken(token) : null;
  if (!session) return res.status(401).json({ ok: false });

  const [{ data: user }, { data: starters, error }] = await Promise.all([
    supabase
      .from("users")
      .select("coding_experience")
      .eq("id", session.userId)
      .maybeSingle(),
    supabase
      .from("sidequests")
      .select("id, name, region, npc, description, reward, difficulty, tags")
      .eq("active", true)
      .eq("starter", true)
      .order("position", { ascending: true })
      .order("id", { ascending: true }),
  ]);
  if (error) return res.json({ ok: true, recommended: null, alternatives: [] });

  const list = starters ?? [];
  const want = EXPERIENCE_DIFFICULTY[String(user?.coding_experience ?? "")] ?? 1;
  // Nearest difficulty to `want`; ties already broken by the position/id order
  // above, so a stable reduce keeps the first (lowest-position) match.
  const recommended =
    list.length === 0
      ? null
      : list.reduce((best, q) => {
          const d = (x: { difficulty?: number | null }) =>
            Math.abs((Number(x.difficulty) || 2) - want);
          return d(q) < d(best) ? q : best;
        }, list[0]);

  res.json({ ok: true, recommended, alternatives: list });
});

export default router;
