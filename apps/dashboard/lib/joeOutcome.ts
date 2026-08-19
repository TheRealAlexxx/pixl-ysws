// One definition of what an incoming Joe outcome does, shared by the webhook
// and the reconcile job so the two can never drift. Deliberately free of any
// database import so it stays a pure unit under test.

export interface IncomingOutcome {
  status: string;
  reason: string | null;
  trustScore: number | null;
  reviewedAt: string | null;
  reviewerName: string | null;
}

export interface OutcomePatch {
  joe_outcome: string;
  joe_reason: string;
  joe_trust_score: number | null;
  joe_reviewed_at: string | null;
  joe_reviewer: string;
  joe_error: string;
  status?: string;
}

// Returns null for an outcome we do not understand, so a malformed delivery is
// dropped rather than written. The status transition happens only out of
// fraud_review: a replayed or overwritten webhook must never drag a decided
// project backwards. A rejection still advances, it is advisory only, and the
// final human reviewer decides.
export function outcomePatch(
  currentStatus: string,
  outcome: IncomingOutcome,
): OutcomePatch | null {
  const status = String(outcome.status ?? "").trim();
  if (status !== "approved" && status !== "rejected") return null;

  const score = outcome.trustScore == null ? NaN : Number(outcome.trustScore);
  const patch: OutcomePatch = {
    joe_outcome: status,
    joe_reason: String(outcome.reason ?? "").trim().slice(0, 1000),
    joe_trust_score: Number.isFinite(score) ? score : null,
    joe_reviewed_at: outcome.reviewedAt ?? null,
    joe_reviewer: String(outcome.reviewerName ?? "").trim(),
    joe_error: "",
  };
  if (currentStatus === "fraud_review") patch.status = "second_review";
  return patch;
}
