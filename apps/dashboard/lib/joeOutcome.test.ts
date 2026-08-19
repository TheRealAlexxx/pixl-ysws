import { describe, expect, test } from "bun:test";
import { outcomePatch } from "./joeOutcome";

const approved = {
  status: "approved",
  reason: null,
  trustScore: 8,
  reviewedAt: "2026-08-15T12:00:00.000Z",
  reviewerName: "Scooter",
};

const rejected = {
  status: "rejected",
  reason: "reused someone else's repo",
  trustScore: 2,
  reviewedAt: "2026-08-15T12:00:00.000Z",
  reviewerName: "Scooter",
};

describe("outcomePatch", () => {
  test("records the outcome and advances a project waiting on fraud", () => {
    const patch = outcomePatch("fraud_review", approved)!;
    expect(patch.status).toBe("second_review");
    expect(patch.joe_outcome).toBe("approved");
    expect(patch.joe_trust_score).toBe(8);
    expect(patch.joe_reviewer).toBe("Scooter");
    expect(patch.joe_reason).toBe("");
  });

  test("a fraud rejection still advances to the human pass", () => {
    const patch = outcomePatch("fraud_review", rejected)!;
    expect(patch.status).toBe("second_review");
    expect(patch.joe_outcome).toBe("rejected");
    expect(patch.joe_reason).toBe("reused someone else's repo");
  });

  test("clears any stored submission error", () => {
    expect(outcomePatch("fraud_review", approved)!.joe_error).toBe("");
  });

  test("does not move a project that already reached the human pass", () => {
    const patch = outcomePatch("second_review", approved)!;
    expect(patch.status).toBeUndefined();
    expect(patch.joe_trust_score).toBe(8);
  });

  test("does not move an already approved project backwards", () => {
    expect(outcomePatch("approved", rejected)!.status).toBeUndefined();
  });

  test("does not move a project that was bounced back to the maker", () => {
    expect(outcomePatch("needs_changes", approved)!.status).toBeUndefined();
  });

  test("tolerates a missing trust score and reviewer", () => {
    const patch = outcomePatch("fraud_review", {
      status: "approved",
      reason: null,
      trustScore: null,
      reviewedAt: null,
      reviewerName: null,
    })!;
    expect(patch.joe_trust_score).toBeNull();
    expect(patch.joe_reviewer).toBe("");
    expect(patch.joe_reviewed_at).toBeNull();
    expect(patch.status).toBe("second_review");
  });

  test("ignores an unrecognised outcome status", () => {
    const patch = outcomePatch("fraud_review", { ...approved, status: "weird" });
    expect(patch).toBeNull();
  });
});
