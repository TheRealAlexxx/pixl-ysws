import { NextResponse } from "next/server";
import { db } from "@/lib/db";
import { fetchProjects, joeEnabled } from "@/lib/joe";
import { applyOutcome, submitToJoe } from "@/lib/joeSync";

export const dynamic = "force-dynamic";

// Joe's webhook has no retries, so this is the safety net: it retries failed
// submissions and picks up any outcome whose delivery was lost.
export async function GET(req: Request) {
  const secret = process.env.CRON_SECRET;
  if (!secret)
    return NextResponse.json({ ok: false, error: "CRON_SECRET is not set" }, { status: 500 });
  if (req.headers.get("authorization") !== `Bearer ${secret}`)
    return NextResponse.json({ ok: false }, { status: 401 });
  if (!joeEnabled()) return NextResponse.json({ ok: true, skipped: "joe is not configured" });

  const { data: waiting, error } = await db
    .from("projects")
    .select("id, joe_project_id, status")
    .eq("status", "fraud_review")
    .limit(500);
  if (error) return NextResponse.json({ ok: false, error: error.message });

  const rows = (waiting ?? []) as { id: number; joe_project_id: string; status: string }[];

  let resubmitted = 0;
  for (const row of rows) {
    if (row.joe_project_id) continue;
    await submitToJoe(row.id);
    resubmitted += 1;
  }

  const known = rows.filter((r) => r.joe_project_id);
  let advanced = 0;
  if (known.length > 0) {
    const joeProjects = await fetchProjects();
    const byId = new Map(joeProjects.map((p) => [p.id, p]));
    for (const row of known) {
      const remote = byId.get(row.joe_project_id);
      if (!remote?.outcome) continue;
      const result = await applyOutcome(row.id, row.status, {
        status: String(remote.outcome.status ?? ""),
        reason: remote.outcome.reason ?? null,
        trustScore: remote.review?.trustScore ?? null,
        reviewedAt: remote.outcome.recordedAt ?? null,
        reviewerName: null,
      });
      if (result.advanced) advanced += 1;
    }
  }

  return NextResponse.json({ ok: true, waiting: rows.length, resubmitted, advanced });
}
