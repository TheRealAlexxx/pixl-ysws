import { Router } from "express";
import { verifySessionToken } from "../auth/session.js";
import { supabase } from "../db/client.js";

const router = Router();

// How many entries the projects page shows. Each source is pulled at this
// depth too, since anything older can't survive the merge anyway.
const LIMIT = 12;

interface Entry {
  kind: string;
  text: string;
  at: string;
}

function push(out: Entry[], kind: string, text: string, at: unknown): void {
  if (typeof at === "string" && at) out.push({ kind, text, at });
}

// The player's own action log, stitched together from the rows the rest of the
// app already writes. There's no activity table on purpose: synthesizing means
// players who've been here since before this endpoint existed still see their
// history instead of an empty panel.
router.get("/api/activity", async (req, res) => {
  const token = typeof req.query.token === "string" ? req.query.token : "";
  const session = token ? verifySessionToken(token) : null;
  if (!session) return res.status(401).json({ ok: false });

  const [{ data: projects }, { data: journals }, { data: txs }, { data: unlocks }] =
    await Promise.all([
      supabase
        .from("projects")
        .select("id, name, created_at, shipped_at, approved_at, rejected_at")
        .eq("user_id", session.userId)
        .is("archived_at", null)
        .order("created_at", { ascending: false })
        .limit(LIMIT),
      supabase
        .from("project_journals")
        .select("project_id, hours, created_at")
        .eq("user_id", session.userId)
        .order("created_at", { ascending: false })
        .limit(LIMIT),
      supabase
        .from("pixel_transactions")
        .select("project_id, amount, reason, created_at")
        .eq("user_id", session.userId)
        .order("created_at", { ascending: false })
        .limit(LIMIT),
      supabase
        .from("sidequest_unlocks")
        .select("sidequest_id, unlocked_at")
        .eq("user_id", session.userId)
        .order("unlocked_at", { ascending: false })
        .limit(LIMIT),
    ]);

  // Journals and transactions only carry a project_id, so names come from a
  // second lookup rather than a join the client would have to understand.
  const names = new Map<number, string>();
  for (const p of projects ?? []) names.set(p.id as number, p.name as string);
  const missing = [
    ...new Set(
      [...(journals ?? []), ...(txs ?? [])]
        .map((r) => r.project_id as number | null)
        .filter((id): id is number => id != null && !names.has(id)),
    ),
  ];
  if (missing.length > 0) {
    const { data } = await supabase
      .from("projects")
      .select("id, name")
      .in("id", missing);
    for (const p of data ?? []) names.set(p.id as number, p.name as string);
  }

  const questNames = new Map<number, string>();
  const questIds = [
    ...new Set((unlocks ?? []).map((u) => u.sidequest_id as number)),
  ];
  if (questIds.length > 0) {
    const { data } = await supabase
      .from("sidequests")
      .select("id, name")
      .in("id", questIds);
    for (const q of data ?? []) questNames.set(q.id as number, q.name as string);
  }

  const out: Entry[] = [];
  for (const p of projects ?? []) {
    const name = p.name as string;
    push(out, "created", `Created project ${name}`, p.created_at);
    push(out, "shipped", `Shipped ${name} for review`, p.shipped_at);
    push(out, "approved", `${name} was approved`, p.approved_at);
    push(out, "rejected", `${name} was rejected`, p.rejected_at);
  }
  for (const j of journals ?? []) {
    const name = names.get(j.project_id as number) ?? "a project";
    const hours = Number(j.hours) || 0;
    push(
      out,
      "journal",
      hours > 0 ? `Logged ${hours}h on ${name}` : `Journalled on ${name}`,
      j.created_at,
    );
  }
  for (const t of txs ?? []) {
    const amount = Math.round(Number(t.amount) || 0);
    if (amount === 0) continue;
    const name = t.project_id != null ? names.get(t.project_id as number) : "";
    const suffix = name ? ` from ${name}` : "";
    push(
      out,
      amount > 0 ? "earned" : "spent",
      amount > 0 ? `+${amount} px${suffix}` : `${amount} px spent`,
      t.created_at,
    );
  }
  for (const u of unlocks ?? []) {
    const name = questNames.get(u.sidequest_id as number);
    if (name) push(out, "trial", `Accepted Trial: ${name}`, u.unlocked_at);
  }

  out.sort((a, b) => new Date(b.at).getTime() - new Date(a.at).getTime());
  res.json({ ok: true, activity: out.slice(0, LIMIT) });
});

export default router;
