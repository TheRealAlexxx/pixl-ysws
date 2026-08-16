# Joe Fraud Review Pass Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Insert Hack Club's Joe fraud platform as a second review pass between Pixl's existing human first pass and its human final pass.

**Architecture:** After a first-pass verdict, the project moves to a new `fraud_review` status and is POSTed to Joe. Joe's fraud team scores it; the outcome arrives either by webhook or by an hourly reconcile job, which moves the project on to `second_review` for the human third pass. A fraud rejection is advisory: it flags the project red but never blocks approval. When `JOE_EVENT_ID`/`JOE_API_KEY` are unset, the whole thing is bypassed and the pipeline behaves exactly as it does today.

**Tech Stack:** Next.js 16 (App Router) in `apps/dashboard`, TypeScript, `bun test`, Orchard Postgres via the Supabase-shaped `lib/pgCompat` wrapper, Orchard Jobs for scheduling.

**Spec:** `docs/superpowers/specs/2026-08-15-joe-fraud-review-pass-design.md`

---

## Ground rules for this codebase

Read these before starting. They override generic habits.

- **`db` is not Supabase.** `apps/dashboard/lib/db.ts:7` re-exports `db` from `./pgCompat`, a Supabase-API-shaped wrapper over Orchard Postgres. `db.from("x").select(...)` works; anything outside that compat surface may not.
- **No em dashes, no `" - "` in prose, no emojis** in code, comments, UI copy or commit messages. Use commas or colons. Existing files use `,` where an em dash would go.
- **Commit messages are plain and casual**, not Conventional Commits. `add the joe client`, not `feat(joe): add client`. No `Co-Authored-By` trailer.
- **Comments are sparse** and explain non-obvious *why*, never *what*.
- **Migration files have drifted from production** (`drizzle/*.sql` could never rebuild the DB). Production is the source of truth. Never run `db:migrate` to "check" state, it applies migrations.
- Tests run with `bun test` from the repo root. `apps/dashboard/tsconfig.json` includes `**/*.ts`, so test files are type-checked by `bun run --cwd apps/dashboard typecheck`. Both were verified to work together.

## File structure

**Created:**

| File | Responsibility |
|---|---|
| `apps/server/drizzle/0118_joe_fraud_review.sql` | Schema record of the new `joe_*` columns |
| `apps/dashboard/lib/joe.ts` | Every outbound call to Joe, plus config and payload building. Nothing else constructs a Joe request. |
| `apps/dashboard/lib/joe.test.ts` | Unit tests for the pure parts of `joe.ts` |
| `apps/dashboard/lib/joeOutcome.ts` | Pure decision logic for what an incoming outcome does. No database, no network. |
| `apps/dashboard/lib/joeOutcome.test.ts` | Unit tests for the decision logic |
| `apps/dashboard/lib/joeSync.ts` | The database-touching half: submit a project, apply an outcome. Shared by the webhook and the cron so both directions have exactly one implementation. |
| `apps/dashboard/app/api/joe/outcome/[key]/route.ts` | Webhook receiver |
| `apps/dashboard/app/api/cron/joe-sync/route.ts` | Submission retry + outcome reconcile |

**Modified:** `apps/dashboard/lib/db.ts` (types, fraud queue listing, status guard), `apps/dashboard/app/actions.ts` (pass-1 destination, force-advance action), `apps/dashboard/app/_components/ProjectBadges.tsx`, `apps/dashboard/app/review/page.tsx`, `apps/dashboard/app/review/[id]/page.tsx`, `apps/dashboard/app/api/cron/queue-health/route.ts`, `apps/dashboard/package.json`, `apps/dashboard/.env.example`, `apps/server/src/routes/sidequests.ts`, `apps/server/src/routes/projects.ts`, `apps/game/scripts/first_project_guide.gd`, `apps/game/web/projects/index.html`.

`joe.ts` and `joeOutcome.ts` are both free of database imports on purpose, so their test files stay pure unit tests. Everything that touches `db` is quarantined in `joeSync.ts`, which is verified end to end in Task 12 rather than unit tested.

**On the webhook secret:** Joe has no webhook authentication feature. It sends only `Content-Type` and nothing else, confirmed by the Joe team. The secret in this plan is therefore entirely ours: we generate it, we embed it in the URL we register, and we check it on the way in. It rides as a **path segment** (`/api/joe/outcome/<secret>`) rather than a query string, because a path segment cannot be dropped by URL normalisation anywhere between Joe's config field and our handler. Nothing is required from Joe's side.

---

### Task 1: Schema

**Files:**
- Create: `apps/server/drizzle/0118_joe_fraud_review.sql`
- Modify: `apps/dashboard/lib/db.ts:135` (end of the `ProjectRow` field list)

- [ ] **Step 1: Confirm nothing constrains `projects.status` in production**

The spec flags this as unverified. A check constraint would make every pass-1 verdict fail once we write `fraud_review`.

Run against production (see the `feedback_prod_db_access_pattern` memory for how to reach Orchard Postgres):

```sql
select conname, pg_get_constraintdef(oid)
from pg_constraint
where conrelid = 'projects'::regclass and contype = 'c';

select column_name, data_type, udt_name
from information_schema.columns
where table_name = 'projects' and column_name = 'status';
```

Expected: `status` is `text`, and no check constraint mentions it. If one exists, add `fraud_review` to it in the migration below before continuing.

- [ ] **Step 2: Write the migration file**

```sql
-- Three-pass review: a first pass (any reviewer) now hands off to Joe
-- (joe.fraud.hackclub.com) for a fraud score, and only then to the final
-- human pass. status 'fraud_review' sits between 'shipped' and 'second_review'.
alter table projects add column if not exists joe_project_id text not null default '';
alter table projects add column if not exists joe_submitted_at timestamptz;
alter table projects add column if not exists joe_trust_score integer;
alter table projects add column if not exists joe_outcome text not null default '';
alter table projects add column if not exists joe_reason text not null default '';
alter table projects add column if not exists joe_reviewed_at timestamptz;
alter table projects add column if not exists joe_reviewer text not null default '';
alter table projects add column if not exists joe_error text not null default '';

create index if not exists projects_joe_project_id_idx on projects (joe_project_id)
  where joe_project_id <> '';
```

The partial index supports the webhook's lookup by `joe_project_id`, which runs on every delivery.

- [ ] **Step 3: Apply it to production**

Run the same DDL directly against Orchard Postgres. Do not run `db:migrate`. Every statement is `if not exists`, so it is safe to re-run.

- [ ] **Step 4: Verify the columns exist**

```sql
select column_name from information_schema.columns
where table_name = 'projects' and column_name like 'joe_%' order by column_name;
```

Expected: 8 rows, `joe_error` through `joe_trust_score`.

- [ ] **Step 5: Add the fields to `ProjectRow`**

In `apps/dashboard/lib/db.ts`, after `eligibility_attested: boolean;` (line 135):

```ts
  // Joe fraud review (joe.fraud.hackclub.com), the second pass. joe_error holds
  // the last submission failure so a stuck project explains itself in the UI.
  joe_project_id: string;
  joe_submitted_at: string | null;
  joe_trust_score: number | null;
  joe_outcome: string;
  joe_reason: string;
  joe_reviewed_at: string | null;
  joe_reviewer: string;
  joe_error: string;
```

- [ ] **Step 6: Typecheck**

Run: `bun run --cwd apps/dashboard typecheck`
Expected: no output, exit 0.

- [ ] **Step 7: Commit**

```bash
git add apps/server/drizzle/0118_joe_fraud_review.sql apps/dashboard/lib/db.ts
git commit -m "add the joe fraud review columns"
```

---

### Task 2: Joe client, pure parts

**Files:**
- Create: `apps/dashboard/lib/joe.ts`
- Create: `apps/dashboard/lib/joe.test.ts`
- Modify: `apps/dashboard/package.json`

- [ ] **Step 1: Add a test script**

In `apps/dashboard/package.json`, add to `scripts` after `"typecheck"`:

```json
    "test": "bun test"
```

- [ ] **Step 2: Write the failing tests**

Create `apps/dashboard/lib/joe.test.ts`:

```ts
import { describe, expect, test } from "bun:test";
import { buildSubmission, organizerPlatformId } from "./joe";

const project = {
  id: 42,
  name: "My Project",
  repo_url: "https://github.com/user/repo",
  demo_url: "https://demo.example.com",
  hackatime_projects: ["my-project"],
  shipped_at: "2026-08-15T12:00:00.000Z",
};

describe("organizerPlatformId", () => {
  test("combines the project id with the ship timestamp", () => {
    expect(organizerPlatformId(42, "2026-08-15T12:00:00.000Z")).toBe("pixl-42-1786881600");
  });

  test("changes when the project is re-shipped", () => {
    const first = organizerPlatformId(42, "2026-08-15T12:00:00.000Z");
    const second = organizerPlatformId(42, "2026-08-16T12:00:00.000Z");
    expect(first).not.toBe(second);
  });

  test("falls back to 0 when the project has never shipped", () => {
    expect(organizerPlatformId(42, null)).toBe("pixl-42-0");
  });
});

describe("buildSubmission", () => {
  test("prefers the slack id as the submitter", () => {
    const result = buildSubmission(project, { slack_id: "U123", email: "a@b.com" });
    expect(result.ok).toBe(true);
    if (!result.ok) return;
    expect(result.body.submitter).toEqual({ slackId: "U123" });
  });

  test("falls back to email when there is no slack id", () => {
    const result = buildSubmission(project, { slack_id: null, email: "a@b.com" });
    expect(result.ok).toBe(true);
    if (!result.ok) return;
    expect(result.body.submitter).toEqual({ email: "a@b.com" });
  });

  test("fails when the submitter cannot be identified", () => {
    const result = buildSubmission(project, { slack_id: null, email: null });
    expect(result.ok).toBe(false);
    if (result.ok) return;
    expect(result.error).toContain("no slack id or email");
  });

  test("fails when there is no code link", () => {
    const result = buildSubmission({ ...project, repo_url: null }, { slack_id: "U123", email: null });
    expect(result.ok).toBe(false);
    if (result.ok) return;
    expect(result.error).toContain("no code link");
  });

  test("omits demoLink when the project has none", () => {
    const result = buildSubmission({ ...project, demo_url: "" }, { slack_id: "U123", email: null });
    expect(result.ok).toBe(true);
    if (!result.ok) return;
    expect(result.body.demoLink).toBeUndefined();
  });

  test("carries the hackatime projects and the dedup id", () => {
    const result = buildSubmission(project, { slack_id: "U123", email: null });
    expect(result.ok).toBe(true);
    if (!result.ok) return;
    expect(result.body.hackatimeProjects).toEqual(["my-project"]);
    expect(result.body.organizerPlatformId).toBe("pixl-42-1786881600");
  });

  test("treats a blank slack id as missing", () => {
    const result = buildSubmission(project, { slack_id: "   ", email: "a@b.com" });
    expect(result.ok).toBe(true);
    if (!result.ok) return;
    expect(result.body.submitter).toEqual({ email: "a@b.com" });
  });
});
```

- [ ] **Step 3: Run the tests to verify they fail**

Run: `bun test apps/dashboard/lib/joe.test.ts`
Expected: FAIL, cannot resolve `./joe`.

- [ ] **Step 4: Write the pure half of the client**

Create `apps/dashboard/lib/joe.ts`:

```ts
// Joe (joe.fraud.hackclub.com) is the second review pass: we submit a project
// after its first pass and their fraud team scores it. Every outbound call to
// Joe lives here.

const DEFAULT_BASE = "https://joe.fraud.hackclub.com/api/v1/ysws";

export interface JoeConfig {
  base: string;
  eventId: string;
  apiKey: string;
}

export interface JoeSubmission {
  name: string;
  codeLink: string;
  demoLink?: string;
  submitter: { slackId: string } | { email: string };
  hackatimeProjects: string[];
  organizerPlatformId: string;
}

export interface SubmittableProject {
  id: number;
  name: string;
  repo_url: string | null;
  demo_url: string | null;
  hackatime_projects: string[] | null;
  shipped_at: string | null;
}

export interface SubmittableOwner {
  slack_id: string | null;
  email: string | null;
}

export type BuildResult =
  | { ok: true; body: JoeSubmission }
  | { ok: false; error: string };

// Unset config disables the whole fraud pass: pass 1 goes straight to
// second_review, exactly as it did before Joe existed.
export function joeConfig(): JoeConfig | null {
  const eventId = (process.env.JOE_EVENT_ID ?? "").trim();
  const apiKey = (process.env.JOE_API_KEY ?? "").trim();
  if (!eventId || !apiKey) return null;
  const base = (process.env.JOE_API_BASE ?? "").trim() || DEFAULT_BASE;
  return { base: base.replace(/\/+$/, ""), eventId, apiKey };
}

export function joeEnabled(): boolean {
  return joeConfig() !== null;
}

// shipped_at is refreshed on every ship, so a re-shipped project gets a fresh
// Joe record instead of colliding with its previous one, while a retried POST
// within the same ship deduplicates to Joe's 200 response.
export function organizerPlatformId(projectId: number, shippedAt: string | null): string {
  const ms = shippedAt ? Date.parse(shippedAt) : NaN;
  const seconds = Number.isFinite(ms) ? Math.floor(ms / 1000) : 0;
  return `pixl-${projectId}-${seconds}`;
}

function clean(value: string | null | undefined): string {
  return String(value ?? "").trim();
}

export function buildSubmission(
  project: SubmittableProject,
  owner: SubmittableOwner,
): BuildResult {
  const codeLink = clean(project.repo_url);
  if (!codeLink) return { ok: false, error: "project has no code link" };

  const slackId = clean(owner.slack_id);
  const email = clean(owner.email);
  if (!slackId && !email)
    return { ok: false, error: "submitter has no slack id or email" };

  const demoLink = clean(project.demo_url);
  return {
    ok: true,
    body: {
      name: project.name,
      codeLink,
      ...(demoLink ? { demoLink } : {}),
      submitter: slackId ? { slackId } : { email },
      hackatimeProjects: project.hackatime_projects ?? [],
      organizerPlatformId: organizerPlatformId(project.id, project.shipped_at),
    },
  };
}
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `bun test apps/dashboard/lib/joe.test.ts`
Expected: PASS, 9 tests.

If `organizerPlatformId` fails on the exact epoch, print `Math.floor(Date.parse("2026-08-15T12:00:00.000Z")/1000)` and correct the expected value in the test rather than the implementation.

- [ ] **Step 6: Typecheck**

Run: `bun run --cwd apps/dashboard typecheck`
Expected: no output, exit 0.

- [ ] **Step 7: Commit**

```bash
git add apps/dashboard/lib/joe.ts apps/dashboard/lib/joe.test.ts apps/dashboard/package.json
git commit -m "joe client payload building"
```

---

### Task 3: Joe client, network calls

**Files:**
- Modify: `apps/dashboard/lib/joe.ts`

No tests here. These are thin `fetch` wrappers whose only logic is already covered by Task 2, and mocking `fetch` to assert we call `fetch` tests nothing. Task 12 verifies them against the live API.

- [ ] **Step 1: Add the submit and list calls**

Append to `apps/dashboard/lib/joe.ts`:

```ts
export interface JoeProjectOutcome {
  status: string;
  reason: string | null;
  recordedAt: string | null;
}

export interface JoeProject {
  id: string;
  organizerPlatformId: string | null;
  review: { trustScore: number | null } | null;
  outcome: JoeProjectOutcome | null;
}

// Never throws. Callers store the error string and let the reconcile job retry.
export async function submitProject(
  project: SubmittableProject,
  owner: SubmittableOwner,
): Promise<{ ok: true; joeProjectId: string } | { ok: false; error: string }> {
  const cfg = joeConfig();
  if (!cfg) return { ok: false, error: "joe is not configured" };

  const built = buildSubmission(project, owner);
  if (!built.ok) return built;

  try {
    const r = await fetch(`${cfg.base}/events/${cfg.eventId}/projects`, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${cfg.apiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(built.body),
      signal: AbortSignal.timeout(10000),
    });
    const text = await r.text();
    if (!r.ok) return { ok: false, error: `joe ${r.status}: ${text.slice(0, 300)}` };
    const json = JSON.parse(text) as { id?: string };
    const id = clean(json.id);
    // 200 means Joe deduplicated on organizerPlatformId and returned the
    // existing record, which is a success for us.
    if (!id) return { ok: false, error: `joe ${r.status}: no id in response` };
    return { ok: true, joeProjectId: id };
  } catch (e) {
    return { ok: false, error: (e as Error).message.slice(0, 300) };
  }
}

export async function fetchProjects(): Promise<JoeProject[]> {
  const cfg = joeConfig();
  if (!cfg) return [];
  try {
    const r = await fetch(`${cfg.base}/events/${cfg.eventId}/projects`, {
      headers: { Authorization: `Bearer ${cfg.apiKey}` },
      signal: AbortSignal.timeout(20000),
    });
    if (!r.ok) {
      console.error("joe fetchProjects failed", r.status);
      return [];
    }
    const json = (await r.json()) as { projects?: JoeProject[] };
    return Array.isArray(json.projects) ? json.projects : [];
  } catch (e) {
    console.error("joe fetchProjects failed", (e as Error).message);
    return [];
  }
}
```

- [ ] **Step 2: Confirm the existing tests still pass**

Run: `bun test apps/dashboard/lib/joe.test.ts`
Expected: PASS, 9 tests.

- [ ] **Step 3: Typecheck**

Run: `bun run --cwd apps/dashboard typecheck`
Expected: no output, exit 0.

- [ ] **Step 4: Commit**

```bash
git add apps/dashboard/lib/joe.ts
git commit -m "joe submit and list calls"
```

---

### Task 4: Outcome handling

**Files:**
- Create: `apps/dashboard/lib/joeOutcome.ts`
- Create: `apps/dashboard/lib/joeOutcome.test.ts`

- [ ] **Step 1: Write the failing tests**

Create `apps/dashboard/lib/joeOutcome.test.ts`:

```ts
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
    const patch = outcomePatch("fraud_review", approved);
    expect(patch.status).toBe("second_review");
    expect(patch.joe_outcome).toBe("approved");
    expect(patch.joe_trust_score).toBe(8);
    expect(patch.joe_reviewer).toBe("Scooter");
    expect(patch.joe_reason).toBe("");
  });

  test("a fraud rejection still advances to the human pass", () => {
    const patch = outcomePatch("fraud_review", rejected);
    expect(patch.status).toBe("second_review");
    expect(patch.joe_outcome).toBe("rejected");
    expect(patch.joe_reason).toBe("reused someone else's repo");
  });

  test("clears any stored submission error", () => {
    expect(outcomePatch("fraud_review", approved).joe_error).toBe("");
  });

  test("does not move a project that already reached the human pass", () => {
    const patch = outcomePatch("second_review", approved);
    expect(patch.status).toBeUndefined();
    expect(patch.joe_trust_score).toBe(8);
  });

  test("does not move an already approved project backwards", () => {
    expect(outcomePatch("approved", rejected).status).toBeUndefined();
  });

  test("does not move a project that was bounced back to the maker", () => {
    expect(outcomePatch("needs_changes", approved).status).toBeUndefined();
  });

  test("tolerates a missing trust score and reviewer", () => {
    const patch = outcomePatch("fraud_review", {
      status: "approved",
      reason: null,
      trustScore: null,
      reviewedAt: null,
      reviewerName: null,
    });
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
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `bun test apps/dashboard/lib/joeOutcome.test.ts`
Expected: FAIL, cannot resolve `./joeOutcome`.

- [ ] **Step 3: Write the implementation**

Create `apps/dashboard/lib/joeOutcome.ts`:

```ts
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

  const score = Number(outcome.trustScore);
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
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `bun test apps/dashboard/lib/joeOutcome.test.ts`
Expected: PASS, 8 tests.

- [ ] **Step 5: Run the whole suite**

Run: `bun test apps/dashboard/lib`
Expected: PASS, 17 tests across 2 files.

- [ ] **Step 6: Typecheck**

Run: `bun run --cwd apps/dashboard typecheck`
Expected: no output, exit 0.

- [ ] **Step 7: Commit**

```bash
git add apps/dashboard/lib/joeOutcome.ts apps/dashboard/lib/joeOutcome.test.ts
git commit -m "joe outcome handling"
```

---

### Task 5: Send projects to Joe after the first pass

**Files:**
- Create: `apps/dashboard/lib/joeSync.ts`
- Modify: `apps/dashboard/app/actions.ts:707-737` (the first-pass branch)

- [ ] **Step 1: Write the database-touching half**

Create `apps/dashboard/lib/joeSync.ts`. This is a plain module, not a server action file, so both the review action and the two route handlers can import it without `"use server"` export restrictions.

```ts
import { db } from "./db";
import { joeEnabled, submitProject } from "./joe";
import { outcomePatch, type IncomingOutcome } from "./joeOutcome";

// Push a first-passed project to Joe. Never throws and never blocks the
// verdict: a failed submission is stored on the row and the reconcile job
// retries it, so a network blip cannot strand a reviewer mid-verdict.
export async function submitToJoe(projectId: number): Promise<void> {
  if (!joeEnabled()) return;
  const { data: project } = await db
    .from("projects")
    .select("id, name, repo_url, demo_url, hackatime_projects, shipped_at, user_id")
    .eq("id", projectId)
    .maybeSingle();
  if (!project) return;
  const { data: owner } = await db
    .from("users")
    .select("slack_id, email")
    .eq("id", project.user_id as string)
    .maybeSingle();

  const result = await submitProject(
    {
      id: project.id as number,
      name: String(project.name),
      repo_url: (project.repo_url as string | null) ?? null,
      demo_url: (project.demo_url as string | null) ?? null,
      hackatime_projects: (project.hackatime_projects as string[] | null) ?? [],
      shipped_at: (project.shipped_at as string | null) ?? null,
    },
    { slack_id: owner?.slack_id ?? null, email: owner?.email ?? null },
  );

  if (result.ok) {
    await db
      .from("projects")
      .update({
        joe_project_id: result.joeProjectId,
        joe_submitted_at: new Date().toISOString(),
        joe_error: "",
      })
      .eq("id", projectId);
    return;
  }
  console.error("joe submit failed", projectId, result.error);
  await db.from("projects").update({ joe_error: result.error }).eq("id", projectId);
}

// Applies an outcome to one project. Idempotent: the status guard means a
// repeated delivery refreshes the joe_* fields and moves nothing.
export async function applyOutcome(
  projectId: number,
  currentStatus: string,
  outcome: IncomingOutcome,
): Promise<{ applied: boolean; advanced: boolean }> {
  const patch = outcomePatch(currentStatus, outcome);
  if (!patch) return { applied: false, advanced: false };

  const query = db.from("projects").update(patch).eq("id", projectId);
  const { error } = patch.status
    ? await query.eq("status", "fraud_review")
    : await query;
  if (error) {
    console.error("applyOutcome failed", projectId, error.message);
    return { applied: false, advanced: false };
  }
  return { applied: true, advanced: Boolean(patch.status) };
}
```

- [ ] **Step 2: Import it in the review action**

Add at the top of `apps/dashboard/app/actions.ts`, alongside the existing `@/lib/*` imports:

```ts
import { joeEnabled } from "@/lib/joe";
import { submitToJoe } from "@/lib/joeSync";
```

- [ ] **Step 3: Send the first pass to `fraud_review` instead of `second_review`**

In the `if (stage === "shipped" && verdict !== "needs_changes")` branch (line 707), change the update's `status` from the literal `"second_review"` to:

```ts
        status: joeEnabled() ? "fraud_review" : "second_review",
```

- [ ] **Step 4: Fire the submission after the audit and payout calls**

In the same branch, immediately after the existing `logModAction(...)` call for `project_first_pass` and before `const nextPath = await nextReviewPath(...)`, add:

```ts
    await submitToJoe(projectId);
```

It is awaited so a fast failure is stored before the reviewer's page navigates, and it cannot throw.

- [ ] **Step 5: Typecheck**

Run: `bun run --cwd apps/dashboard typecheck`
Expected: no output, exit 0.

- [ ] **Step 6: Confirm nothing else needs the new status**

Run: `grep -n "second_review" apps/dashboard/lib/db.ts`

Confirm that `countPendingReviews` (lines 676 and 686) and `nextReviewId` (lines 573-582) enumerate statuses explicitly. They do, so `fraud_review` is excluded from the working queue by construction and needs no edit. Task 9 adds its own listing.

- [ ] **Step 7: Commit**

```bash
git add apps/dashboard/app/actions.ts
git commit -m "send first-passed projects to joe"
```

---

### Task 6: Webhook receiver

**Files:**
- Create: `apps/dashboard/app/api/joe/outcome/[key]/route.ts`

- [ ] **Step 1: Write the route**

```ts
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
```

- [ ] **Step 2: Typecheck**

Run: `bun run --cwd apps/dashboard typecheck`
Expected: no output, exit 0.

- [ ] **Step 3: Commit**

```bash
git add "apps/dashboard/app/api/joe/outcome/[key]/route.ts"
git commit -m "joe outcome webhook"
```

---

### Task 7: Reconcile job endpoint

**Files:**
- Create: `apps/dashboard/app/api/cron/joe-sync/route.ts`

- [ ] **Step 1: Write the route**

```ts
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
```

Note the reconcile path has no `reviewerName`: the list endpoint does not return one. That field is populated only by the webhook, which is why it can legitimately be empty on a project recovered this way.

- [ ] **Step 2: Typecheck**

Run: `bun run --cwd apps/dashboard typecheck`
Expected: no output, exit 0.

- [ ] **Step 3: Commit**

```bash
git add apps/dashboard/app/api/cron/joe-sync/route.ts
git commit -m "joe reconcile job endpoint"
```

---

### Task 8: Schedule the reconcile job on Orchard

**Files:** none, this is infrastructure.

`apps/dashboard/vercel.json` crons do not run: the dashboard is deployed on Orchard and the YSWS org has zero Orchard jobs. Do not add the schedule there.

- [ ] **Step 1: Create the Orchard job**

Use `mcp__orchard__create_job` with:

- `projectId`: `4cab3f21-917c-4eef-bee9-707e94322752`
- `name`: `joe-sync`
- `description`: `Hourly retry of Joe submissions and reconcile of missed outcome webhooks`
- `scheduleCron`: `7 * * * *`
- `concurrencyPolicy`: `forbid`
- `steps`: one step of `type: "app"`, `deploymentId: "62620673-2876-4ce3-a387-873e969756c5"`, `name: "call joe-sync"`, `timeoutSeconds: 300`, and:

```bash
node -e 'fetch("https://dash.pixl.hackclub.com/api/cron/joe-sync",{headers:{Authorization:"Bearer "+process.env.CRON_SECRET}}).then(async r=>{const t=await r.text();console.log(r.status,t);if(!r.ok)process.exit(1)}).catch(e=>{console.error(e.message);process.exit(1)})'
```

An `app` step runs in the dashboard's own image with its env, so `CRON_SECRET` is read from the deployment rather than pasted into the job definition. Minute 7 avoids the top-of-hour spike.

- [ ] **Step 2: Trigger it once and check the run**

Use `mcp__orchard__run_job`, then `mcp__orchard__get_job_run_logs`.
Expected: `200 {"ok":true,"waiting":0,"resubmitted":0,"advanced":0}` while no project is in `fraud_review`.

- [ ] **Step 3: Commit**

Nothing to commit. Record the job id in the PR description.

---

### Task 9: Fraud stage in the review queue

**Files:**
- Modify: `apps/dashboard/app/_components/ProjectBadges.tsx:23-29`
- Modify: `apps/dashboard/lib/db.ts:517` and after line 555
- Modify: `apps/dashboard/app/review/page.tsx:36`

- [ ] **Step 1: Add the status badge**

In `ProjectBadges.tsx`, add to the `STATUS` map after the `shipped` entry:

```ts
  fraud_review: { label: "Fraud review", tone: "blue", dot: "bg-blue-500" },
```

- [ ] **Step 2: Include the fraud stage in the "being reviewed" guard**

In `lib/db.ts:517`, inside `notifyReviewStarted`, change:

```ts
  if (!p || (p.status !== "shipped" && p.status !== "second_review")) return;
```

to:

```ts
  if (!p || !["shipped", "fraud_review", "second_review"].includes(String(p.status))) return;
```

- [ ] **Step 3: Add the fraud queue listing**

In `lib/db.ts`, after `listSecondReviewProjects` (ends line 555):

```ts
// Waiting on Joe: not actionable by anyone, shown read-only so a backlog or a
// failed submission is visible instead of silent. Oldest first.
export async function listFraudReviewProjects(): Promise<ShippedProject[]> {
  const { data, error } = await db
    .from("projects")
    .select("*, users(id, display_name, real_name, slack_id)")
    .eq("status", "fraud_review")
    .is("archived_at", null)
    .is("rejected_at", null)
    .is("banned_at", null)
    .order("first_pass_at", { ascending: true })
    .limit(500);
  if (error) {
    console.error("listFraudReviewProjects", error.message);
    return [];
  }
  return hydrateHours((data ?? []) as ShippedProject[]);
}
```

- [ ] **Step 4: Render it for final reviewers**

In `apps/dashboard/app/review/page.tsx`, next to the existing line 36:

```ts
  const fraudRows = access.canSecondPass ? await listFraudReviewProjects() : [];
```

Import `listFraudReviewProjects` alongside `listSecondReviewProjects`.

Render it directly above the existing `{finalRows.length > 0 && (` block, mirroring that section's header idiom (dot, `h2`, count `Badge`) but with no action links, since nothing here is actionable:

```tsx
{fraudRows.length > 0 && (
  <div className="mb-8">
    <div className="flex items-center gap-2 mb-3">
      <span className="w-1.5 h-1.5 rounded-full bg-blue-500" />
      <h2 className="text-sm font-semibold text-foreground">
        Waiting on fraud review
        <Badge variant="info" className="ml-2">
          {fraudRows.length}
        </Badge>
      </h2>
    </div>
    <p className="text-xs text-muted-foreground mb-3">
      Joe is scoring these. They move to your final pass on their own.
    </p>
    <ul className="text-sm space-y-1">
      {fraudRows.map((p) => (
        <li key={p.id} className="flex items-center gap-2">
          <a href={`/review/${p.id}`} className="hover:underline">
            {p.name}
          </a>
          <span className="text-xs text-muted-foreground">
            {p.first_pass_at
              ? `waiting ${Math.floor((Date.now() - new Date(p.first_pass_at).getTime()) / 86_400_000)}d`
              : "waiting"}
          </span>
          {p.joe_error && (
            <span className="text-xs text-rose-600">not submitted: {p.joe_error}</span>
          )}
        </li>
      ))}
    </ul>
  </div>
)}
```

`Badge` is already imported in this file for the final-pass count. Confirm `variant="info"` exists in `components/ui/badge`; `ProjectBadges.tsx` maps the `blue` tone to it, so it does.

- [ ] **Step 5: Typecheck**

Run: `bun run --cwd apps/dashboard typecheck`
Expected: no output, exit 0.

- [ ] **Step 6: Commit**

```bash
git add apps/dashboard/app/_components/ProjectBadges.tsx apps/dashboard/lib/db.ts apps/dashboard/app/review/page.tsx
git commit -m "show the fraud review queue"
```

---

### Task 10: Fraud panel on the review page

**Files:**
- Modify: `apps/dashboard/app/review/[id]/page.tsx` (near the existing status and Hackatime panels)

- [ ] **Step 1: Add the panel**

Inside the project detail page, above the verdict form, render:

```tsx
{(p.joe_project_id || p.joe_error) && (
  <Card className="p-5 gap-0 space-y-2">
    <div className="text-sm font-semibold">Fraud review (Joe)</div>
    {p.joe_error ? (
      <p className="text-sm text-rose-600">
        Not submitted to Joe: {p.joe_error}
      </p>
    ) : p.joe_outcome ? (
      <dl className="text-sm grid grid-cols-2 gap-1">
        <dt>Outcome</dt>
        <dd>{p.joe_outcome}</dd>
        <dt>Trust score</dt>
        <dd>{p.joe_trust_score ?? "not given"}</dd>
        {p.joe_reason && (
          <>
            <dt>Reason</dt>
            <dd>{p.joe_reason}</dd>
          </>
        )}
        <dt>Reviewer</dt>
        <dd>{p.joe_reviewer || "unknown"}</dd>
        <dt>Reviewed</dt>
        <dd>{p.joe_reviewed_at ? new Date(p.joe_reviewed_at).toLocaleString() : "not yet"}</dd>
      </dl>
    ) : (
      <p className="text-sm text-muted-foreground">
        Submitted to Joe, waiting on a score.
      </p>
    )}
  </Card>
)}
```

This uses the page's existing `Card` component (already imported there, used as `<Card className="p-5 gap-0">` for the verdict panel), so it sits flush with the panels around it.

- [ ] **Step 2: Add the rejection banner**

Above the verdict form, only on the final stage:

```tsx
{isFinalStage && p.joe_outcome === "rejected" && (
  <Card className="p-5 text-sm gap-0 ring-rose-300 dark:ring-rose-500/30 text-rose-700 dark:text-rose-300">
    <strong>Joe rejected this on fraud review.</strong>{" "}
    {p.joe_reason || "No reason given."} You can still approve it, but document
    why in your notes.
  </Card>
)}
```

It must not disable any control. The final reviewer decides.

- [ ] **Step 3: Typecheck**

Run: `bun run --cwd apps/dashboard typecheck`
Expected: no output, exit 0.

- [ ] **Step 4: Commit**

```bash
git add "apps/dashboard/app/review/[id]/page.tsx"
git commit -m "show joe's verdict on the review page"
```

---

### Task 11: Force-advance a stuck project

**Files:**
- Modify: `apps/dashboard/app/actions.ts`
- Modify: `apps/dashboard/app/review/[id]/page.tsx`

- [ ] **Step 1: Add the server action**

In `actions.ts`, near the other review actions:

```ts
// Escape hatch for a project Joe never scores, or one that could not be
// submitted at all. Only a final reviewer, always logged, always with a reason.
export async function forceAdvanceFraud(formData: FormData): Promise<void> {
  const access = await requirePerm("review");
  if (!access.canSecondPass)
    redirect(`/review?error=${encodeURIComponent("Only a final reviewer can skip the fraud pass.")}`);
  const projectId = Number(formData.get("projectId") ?? 0);
  const reason = String(formData.get("reason") ?? "").trim().slice(0, 500);
  const back = `/review/${projectId}`;
  if (!projectId) redirect("/review");
  if (!reason)
    redirect(`${back}?error=${encodeURIComponent("Give a reason for skipping the fraud pass.")}`);

  const { data: project, error } = await db
    .from("projects")
    .update({ status: "second_review" })
    .eq("id", projectId)
    .eq("status", "fraud_review")
    .select("id, name, user_id")
    .single();
  if (error || !project) {
    redirect(`${back}?error=${encodeURIComponent("This project isn't waiting on fraud review.")}`);
  }

  await logModAction(
    project.user_id as string,
    "project_fraud_override",
    `${project.name}: skipped the fraud pass , ${reason}`,
    actorName(access),
  );
  revalidatePath("/review");
  redirect(back);
}
```

- [ ] **Step 2: Add the form**

In the fraud panel from Task 10, when `p.status === "fraud_review"` and the viewer `canSecondPass`:

```tsx
<form action={forceAdvanceFraud} className="flex gap-2 pt-2">
  <input type="hidden" name="projectId" value={p.id} />
  <input
    name="reason"
    required
    placeholder="Why skip the fraud pass?"
    className="flex-1 rounded border px-2 py-1 text-sm"
  />
  <button type="submit" className="rounded border px-3 py-1 text-sm">
    Skip to final review
  </button>
</form>
```

- [ ] **Step 3: Typecheck**

Run: `bun run --cwd apps/dashboard typecheck`
Expected: no output, exit 0.

- [ ] **Step 4: Commit**

```bash
git add apps/dashboard/app/actions.ts "apps/dashboard/app/review/[id]/page.tsx"
git commit -m "let a final reviewer skip a stuck fraud pass"
```

---

### Task 12: Verify against the live API and the running app

**Files:** none.

This is the real verification. Report exactly what was run and what came back. Do not claim anything passed without pasting the output.

- [ ] **Step 1: Confirm the credentials still work**

```bash
cd apps/dashboard && set -a && . ./.env && set +a
curl -s -o /dev/null -w '%{http_code}\n' \
  -H "Authorization: Bearer $JOE_API_KEY" \
  "$JOE_API_BASE/events/$JOE_EVENT_ID/projects"
```

Expected: `200`.

- [ ] **Step 2: Start the dashboard**

Run: `bun run --cwd apps/dashboard dev`
Expected: ready on port 4900.

- [ ] **Step 3: Reject the webhook without the secret**

```bash
curl -s -o /dev/null -w '%{http_code}\n' -X POST \
  -H 'Content-Type: application/json' \
  -d '{"event":"outcome.set"}' \
  'http://localhost:4900/api/joe/outcome/wrong-secret'
```

Expected: `401`.

- [ ] **Step 4: Drive a project through the whole flow**

Pick a test project in the local database, set it to `fraud_review` with a known `joe_project_id`:

```sql
update projects set status = 'fraud_review', joe_project_id = 'test-uuid-1' where id = <ID>;
```

Post an approved outcome:

```bash
cd apps/dashboard && set -a && . ./.env && set +a
curl -s -X POST -H 'Content-Type: application/json' \
  -d '{"event":"outcome.set","projectId":"test-uuid-1","outcome":{"status":"approved","reason":null,"trustScore":8,"reviewedAt":"2026-08-15T12:00:00.000Z","reviewerName":"Scooter"}}' \
  "http://localhost:4900/api/joe/outcome/$JOE_WEBHOOK_SECRET"
```

Expected: `{"ok":true,"applied":true,"advanced":true}`, and the row is now `second_review` with `joe_trust_score = 8`.

- [ ] **Step 5: Replay the same delivery**

Run the exact same curl again.
Expected: `{"ok":true,"applied":true,"advanced":false}`, and the row stays `second_review`. This is the idempotency check.

- [ ] **Step 6: Confirm a rejection still advances**

Reset to `fraud_review`, post the same payload with `"status":"rejected","reason":"copied repo","trustScore":2`.
Expected: `advanced: true`, row at `second_review`, and the review page shows the red banner.

- [ ] **Step 7: Confirm an approved project cannot be dragged backwards**

With the row at `approved`, post the outcome again.
Expected: `{"ok":true,"applied":true,"advanced":false}` and the status stays `approved`.

- [ ] **Step 8: Run the reconcile endpoint**

```bash
curl -s -H "Authorization: Bearer $CRON_SECRET" \
  'http://localhost:4900/api/cron/joe-sync'
```

Expected: `{"ok":true,"waiting":N,...}` with no error.

- [ ] **Step 9: Reset the test project**

```sql
update projects set status = '<original>', joe_project_id = '', joe_outcome = '',
  joe_trust_score = null, joe_reason = '', joe_reviewer = '', joe_reviewed_at = null
where id = <ID>;
```

- [ ] **Step 10: Full suite and typecheck**

Run: `bun test apps/dashboard/lib && bun run --cwd apps/dashboard typecheck`
Expected: 17 tests pass, typecheck silent.

---

### Task 13: Treat the fraud stage as "in review" for players

**Files:**
- Modify: `apps/server/src/routes/sidequests.ts:35`
- Modify: `apps/server/src/routes/projects.ts:559` and `:665`
- Modify: `apps/game/scripts/first_project_guide.gd:169`
- Modify: `apps/game/web/projects/index.html:1806`

Players never see the fraud stage named. Missing any of these silently makes projects uneditable or drops them out of Trial counts mid-review.

- [ ] **Step 1: Trial progress counting**

`apps/server/src/routes/sidequests.ts:35`:

```ts
        .in("status", ["shipped", "fraud_review", "second_review", "approved"]),
```

- [ ] **Step 2: Edit-while-in-review guard**

`apps/server/src/routes/projects.ts:559`:

```ts
  if (!["shipped", "fraud_review", "second_review"].includes(project.status))
```

Keep the existing error response and message unchanged.

- [ ] **Step 3: Timeline events**

`apps/server/src/routes/projects.ts:665`:

```ts
  if (proj?.shipped_at && ["shipped", "fraud_review", "second_review"].includes(proj.status))
```

- [ ] **Step 4: Godot first-project guide**

`apps/game/scripts/first_project_guide.gd:169`:

```gdscript
		if st == "shipped" or st == "fraud_review" or st == "second_review" or st == "approved":
```

- [ ] **Step 5: Projects web page**

`apps/game/web/projects/index.html:1806`:

```js
        const inReview = p.status === "shipped" || p.status === "fraud_review" || p.status === "second_review";
```

- [ ] **Step 6: Confirm nothing was missed**

Run: `grep -rn "second_review" apps/server/src apps/game --include=*.ts --include=*.gd --include=*.html`

Every hit must now also mention `fraud_review`.

- [ ] **Step 7: Commit**

```bash
git add apps/server/src/routes/sidequests.ts apps/server/src/routes/projects.ts apps/game/scripts/first_project_guide.gd apps/game/web/projects/index.html
git commit -m "count the fraud pass as in review for players"
```

---

### Task 14: Queue health and docs

**Files:**
- Modify: `apps/dashboard/app/api/cron/queue-health/route.ts:26-45`
- Modify: `apps/dashboard/.env.example`

- [ ] **Step 1: Include the fraud stage in the queue alert**

In `queue-health/route.ts`, add `"fraud_review"` to the `.in("status", [...])` on line 26, and extend the message built around line 45 with a stuck-in-fraud count so a backlog is visible rather than silent:

```ts
  const fraud = rows.filter((r) => r.status === "fraud_review").length;
```

and include `(${fraud} waiting on fraud)` in the alert text when `fraud > 0`. Follow the existing string-building style in that file.

Note in the PR description that this cron does not currently fire at all: it is configured in `apps/dashboard/vercel.json` but the dashboard runs on Orchard. Fixing that is out of scope here.

- [ ] **Step 2: Document the environment**

Add to `apps/dashboard/.env.example`, with empty values only, never the real key:

```
# Joe fraud review (the second review pass). Unset JOE_EVENT_ID or JOE_API_KEY
# to bypass the fraud pass entirely: first pass then goes straight to the final
# human pass, as it did before Joe existed.
JOE_API_BASE=https://joe.fraud.hackclub.com/api/v1/ysws
JOE_EVENT_ID=pixl
JOE_API_KEY=
JOE_WEBHOOK_SECRET=
# One-time per environment, once /api/joe/outcome is deployed:
#   curl -X PATCH "$JOE_API_BASE/events/$JOE_EVENT_ID" \
#     -H "Authorization: Bearer $JOE_API_KEY" -H 'Content-Type: application/json' \
#     -d '{"outcomeWebhookUrl":"https://dash.pixl.hackclub.com/api/joe/outcome/<JOE_WEBHOOK_SECRET>"}'
```

- [ ] **Step 3: Confirm no secret is staged**

Run: `git diff --cached | grep -c "ysws_"`
Expected: `0`.

- [ ] **Step 4: Commit**

```bash
git add apps/dashboard/app/api/cron/queue-health/route.ts apps/dashboard/.env.example
git commit -m "queue health counts the fraud stage"
```

---

### Task 15: Register the webhook

**Files:** none. **Blocked** until the webhook URL is confirmed.

Do not run this until `/api/joe/outcome` is deployed. Registering a URL that 404s means outcomes are silently lost, and Joe does not retry.

- [ ] **Step 1: Register the URL**

```bash
cd apps/dashboard && set -a && . ./.env && set +a
curl -s -X PATCH "$JOE_API_BASE/events/$JOE_EVENT_ID" \
  -H "Authorization: Bearer $JOE_API_KEY" \
  -H 'Content-Type: application/json' \
  -d "{\"outcomeWebhookUrl\":\"https://dash.pixl.hackclub.com/api/joe/outcome/$JOE_WEBHOOK_SECRET\"}"
```

Expected: `{"status":"success","message":"Webhook URL updated."}`.

- [ ] **Step 2: Confirm end to end**

Ship a real test project, first-pass it, confirm it appears in Joe's list endpoint, and have Joe record an outcome. Confirm the project reaches `second_review` without the reconcile job running.

---

## Rollback

The kill switch is the rollback. Removing `JOE_EVENT_ID` or `JOE_API_KEY` from the `pixl-dashboard` deployment makes pass 1 write `second_review` again and stops all Joe calls. Any project already sitting in `fraud_review` must then be force-advanced (Task 11) or moved with a single `update projects set status = 'second_review' where status = 'fraud_review'`. The `joe_*` columns are additive and can stay.
