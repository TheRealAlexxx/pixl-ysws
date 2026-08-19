import { NextResponse } from "next/server";
import { db } from "@/lib/db";
import { applyOutcome } from "@/lib/joeSync";

export const dynamic = "force-dynamic";

// Joe posts here whenever a project outcome is recorded. It has no webhook
// authentication of its own and sends only Content-Type, so the secret is ours
// and rides in the path: a path segment survives any URL normalisation between
// Joe's config field and here, which a query string might not.
// Delivery is fire-and-forget with no retries, so everything is done before
// responding and the hourly reconcile job covers whatever is still lost.
export async function POST(req: Request, ctx: { params: Promise<{ key: string }> }) {
  const secret = process.env.JOE_WEBHOOK_SECRET;
  if (!secret)
    return NextResponse.json(
      { ok: false, error: "JOE_WEBHOOK_SECRET is not set" },
      { status: 500 },
    );
  const { key } = await ctx.params;
  if (key !== secret) return NextResponse.json({ ok: false }, { status: 401 });

  let body: {
    event?: string;
    projectId?: string;
    outcome?: {
      status?: string;
      reason?: string | null;
      trustScore?: number | null;
      reviewedAt?: string | null;
      reviewerName?: string | null;
    };
  };
  try {
    body = await req.json();
  } catch {
    return NextResponse.json({ ok: false, error: "invalid json" }, { status: 400 });
  }

  if (body.event !== "outcome.set") return NextResponse.json({ ok: true, ignored: true });

  const joeProjectId = String(body.projectId ?? "").trim();
  if (!joeProjectId || !body.outcome)
    return NextResponse.json({ ok: false, error: "missing projectId or outcome" }, { status: 400 });

  const { data: project } = await db
    .from("projects")
    .select("id, status")
    .eq("joe_project_id", joeProjectId)
    .maybeSingle();
  if (!project) {
    console.error("joe webhook for unknown project", joeProjectId);
    return NextResponse.json({ ok: true, unknown: true });
  }

  const result = await applyOutcome(project.id as number, String(project.status), {
    status: String(body.outcome.status ?? ""),
    reason: body.outcome.reason ?? null,
    trustScore: body.outcome.trustScore ?? null,
    reviewedAt: body.outcome.reviewedAt ?? null,
    reviewerName: body.outcome.reviewerName ?? null,
  });

  return NextResponse.json({ ok: true, ...result });
}
