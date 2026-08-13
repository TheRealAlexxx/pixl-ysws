import { Router } from "express";
import { verifySessionToken } from "../auth/session.js";
import { supabase } from "../db/client.js";
import { withLock } from "../db/advisoryLock.js";

const router = Router();

// A user's upvote balance = (upvotes received across their projects) - (upvotes
// already spent on collectibles). Kept as a derived value so upvotes stay a
// simple permanent ledger rather than a mutable counter.
async function upvoteBalance(userId: string): Promise<number> {
  const { data: mine } = await supabase
    .from("projects")
    .select("id")
    .eq("user_id", userId);
  const ids = (mine ?? []).map((p) => p.id as number);
  let received = 0;
  if (ids.length > 0) {
    const { count } = await supabase
      .from("project_upvotes")
      .select("id", { count: "exact", head: true })
      .in("project_id", ids);
    received = count ?? 0;
  }
  const { data: spends } = await supabase
    .from("collectible_purchases")
    .select("cost")
    .eq("user_id", userId);
  const spent = (spends ?? []).reduce((s, r) => s + Number(r.cost), 0);
  return Math.max(0, received - spent);
}

// Permanent upvote on an approved project. One per voter, never taken back, and
// you can't upvote your own work. Idempotent — re-hitting it is a no-op.
router.post("/api/projects/:id/upvote", async (req, res) => {
  const token = typeof req.query.token === "string" ? req.query.token : "";
  const session = token ? verifySessionToken(token) : null;
  if (!session) return res.status(401).json({ ok: false });

  const id = Number(req.params.id);
  if (!Number.isFinite(id)) return res.status(400).json({ ok: false, error: "bad_id" });

  const { data: project } = await supabase
    .from("projects")
    .select("id, user_id, status")
    .eq("id", id)
    .is("archived_at", null)
    .is("banned_at", null)
    .maybeSingle();
  if (!project || project.status !== "approved")
    return res.status(404).json({ ok: false, error: "not_found" });
  if (project.user_id === session.userId)
    return res.status(400).json({ ok: false, error: "own_project" });

  try {
    // A lock scoped to this (project, voter) pair closes the race where a
    // concurrent upvote and downvote for the same project each read "no
    // opposite vote exists" before either writes, leaving the voter holding
    // both directions at once.
    const result = await withLock(
      `project_vote:${id}:${session.userId}`,
      async (tx) => {
        const existingDownvote = (
          await tx`select id from project_downvotes where project_id = ${id} and voter_id = ${session.userId}`
        )[0];
        if (existingDownvote) return { error: "already_downvoted" as const };

        await tx`insert into project_upvotes (project_id, voter_id) values (${id}, ${session.userId}) on conflict do nothing`;
        const [{ n }] =
          await tx`select count(*)::int as n from project_upvotes where project_id = ${id}`;
        return { upvotes: n as number };
      },
    );
    if ("error" in result) return res.status(400).json({ ok: false, error: result.error });
    res.json({ ok: true, upvotes: result.upvotes, has_upvoted: true });
  } catch (e) {
    console.error("[upvotes] insert failed", e);
    res.status(500).json({ ok: false });
  }
});

// Permanent downvote on an approved project. Same rules as upvote (one per
// voter, never taken back, can't vote your own project), plus: a voter can't
// downvote a project they've already upvoted, or upvote one they've already
// downvoted — only one direction per voter per project. Doesn't touch the
// upvote currency/balance; it's a signal, not a spend.
router.post("/api/projects/:id/downvote", async (req, res) => {
  const token = typeof req.query.token === "string" ? req.query.token : "";
  const session = token ? verifySessionToken(token) : null;
  if (!session) return res.status(401).json({ ok: false });

  const id = Number(req.params.id);
  if (!Number.isFinite(id)) return res.status(400).json({ ok: false, error: "bad_id" });

  const { data: project } = await supabase
    .from("projects")
    .select("id, user_id, status")
    .eq("id", id)
    .is("archived_at", null)
    .is("banned_at", null)
    .maybeSingle();
  if (!project || project.status !== "approved")
    return res.status(404).json({ ok: false, error: "not_found" });
  if (project.user_id === session.userId)
    return res.status(400).json({ ok: false, error: "own_project" });

  try {
    const result = await withLock(
      `project_vote:${id}:${session.userId}`,
      async (tx) => {
        const existingUpvote = (
          await tx`select id from project_upvotes where project_id = ${id} and voter_id = ${session.userId}`
        )[0];
        if (existingUpvote) return { error: "already_upvoted" as const };

        await tx`insert into project_downvotes (project_id, voter_id) values (${id}, ${session.userId}) on conflict do nothing`;
        const [{ n }] =
          await tx`select count(*)::int as n from project_downvotes where project_id = ${id}`;
        return { downvotes: n as number };
      },
    );
    if ("error" in result) return res.status(400).json({ ok: false, error: result.error });
    res.json({ ok: true, downvotes: result.downvotes, has_downvoted: true });
  } catch (e) {
    console.error("[downvotes] insert failed", e);
    res.status(500).json({ ok: false });
  }
});

// The signed-in player's spendable upvote balance ("upvote account").
router.get("/api/upvotes/balance", async (req, res) => {
  const token = typeof req.query.token === "string" ? req.query.token : "";
  const session = token ? verifySessionToken(token) : null;
  if (!session) return res.status(401).json({ ok: false });
  res.json({ ok: true, balance: await upvoteBalance(session.userId) });
});

// Collectibles catalog + what the player already owns + their balance.
router.get("/api/collectibles", async (req, res) => {
  const token = typeof req.query.token === "string" ? req.query.token : "";
  const session = token ? verifySessionToken(token) : null;
  if (!session) return res.status(401).json({ ok: false });

  const [{ data: items }, { data: owned }, balance] = await Promise.all([
    supabase
      .from("collectibles")
      .select("id, name, description, image_url, cost")
      .eq("active", true)
      .order("position", { ascending: true })
      .order("id", { ascending: true }),
    supabase
      .from("collectible_purchases")
      .select("collectible_id")
      .eq("user_id", session.userId),
    upvoteBalance(session.userId),
  ]);
  const ownedSet = new Set((owned ?? []).map((r) => r.collectible_id as number));
  res.json({
    ok: true,
    balance,
    collectibles: (items ?? []).map((c) => ({ ...c, owned: ownedSet.has(c.id as number) })),
  });
});

// Buy a collectible with upvotes. Guards: exists/active, not already owned,
// enough balance. The unique(user_id, collectible_id) constraint is the final
// backstop against a double-spend race.
router.post("/api/collectibles/:id/buy", async (req, res) => {
  const token = typeof req.query.token === "string" ? req.query.token : "";
  const session = token ? verifySessionToken(token) : null;
  if (!session) return res.status(401).json({ ok: false });

  const id = Number(req.params.id);
  if (!Number.isFinite(id)) return res.status(400).json({ ok: false, error: "bad_id" });

  try {
    // Locked per-user (not per-item): the balance is derived across every
    // collectible the user owns, so two concurrent buys of *different*
    // items could otherwise both read the same sufficient balance and both
    // succeed, overspending it.
    const result = await withLock(`collectible_buy:${session.userId}`, async (tx) => {
      const item = (
        await tx`select id, cost, active from collectibles where id = ${id}`
      )[0] as { id: number; cost: number; active: boolean } | undefined;
      if (!item || !item.active) return { error: "not_found" as const };

      const already = (
        await tx`select id from collectible_purchases where user_id = ${session.userId} and collectible_id = ${id}`
      )[0];
      if (already) return { error: "already_owned" as const };

      const ownedProjects =
        await tx`select id from projects where user_id = ${session.userId}`;
      const ids = ownedProjects.map((p) => p.id as number);
      let received = 0;
      if (ids.length > 0) {
        const [{ n }] =
          await tx`select count(*)::int as n from project_upvotes where project_id = any(${ids})`;
        received = n as number;
      }
      const spends =
        await tx`select cost from collectible_purchases where user_id = ${session.userId}`;
      const spent = spends.reduce((s, r) => s + Number(r.cost), 0);
      const balance = Math.max(0, received - spent);

      const cost = Number(item.cost);
      if (balance < cost)
        return { error: "insufficient_upvotes" as const, balance, cost };

      await tx`insert into collectible_purchases (user_id, collectible_id, cost) values (${session.userId}, ${id}, ${cost})`;
      return { balance: balance - cost };
    });

    if ("error" in result) {
      const status = result.error === "not_found" ? 404 : 400;
      return res.status(status).json({ ok: false, ...result });
    }
    res.json({ ok: true, balance: result.balance });
  } catch (e) {
    console.error("[collectibles] buy failed", e);
    res.status(500).json({ ok: false });
  }
});

export default router;
