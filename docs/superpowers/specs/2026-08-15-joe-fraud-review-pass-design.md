# Joe fraud review as the second pass

Insert Hack Club's Joe fraud platform (`joe.fraud.hackclub.com`) into the Pixl
project review pipeline as a new second pass, moving the existing human final
pass to third.

Today `reviewProject` in `apps/dashboard/app/actions.ts` runs two passes: a first
pass from any reviewer (whose approve/ban verdict is only a proposal) and a final
pass from a different final reviewer, which credits pixels. This adds a fraud
stage between them.

## Decisions

Taken from the brainstorming session, recorded so implementation does not
re-litigate them:

- Joe's own fraud team produces the trust score. Pixl never calls
  `POST /review`. We submit the project and wait for the outcome.
- A fraud rejection is advisory, not terminal. The project still reaches the
  human third pass, flagged, and the final reviewer can still approve it.
- Projects are submitted to Joe only after the first pass clears, so bounced and
  junk submissions never reach Joe.
- Pixl does not call `POST /outcome`. The integration is read-only in that
  direction; our final verdict stays in Pixl.
- The `second_review` status value is kept as-is in the database and relabelled
  in the UI. Renaming it to `final_review` would touch roughly thirty call sites
  across two apps plus a production data migration, for no behavioural gain. Its
  badge already reads "Final review".
- All the code lives in `apps/dashboard`. It already owns the review pipeline,
  the review queue, the cron and the Slack alerts; `apps/server` only ever reads
  project status.

## Flow

```
shipped ──pass 1──> fraud_review ──Joe outcome──> second_review ──pass 3──> approved / banned
   │                                                (UI: "Final review")
   └── "request changes" ──> needs_changes          (skips Joe entirely)
```

Pass 1 is otherwise unchanged: approve and ban stay proposals, the
`first_pass_*` columns are still written, and `recordPendingPayout` still fires.
The only change is the destination status. `settleFirstPassPayouts` still runs at
pass 3, so no payout code changes at all.

### Kill switch

When `JOE_EVENT_ID` or `JOE_API_KEY` is unset, pass 1 writes `second_review`
exactly as it does today and no Joe code runs. Local development, and any
prolonged Joe outage, degrade to the current two-pass pipeline rather than
jamming the queue.

## 1. Migration

`apps/server/drizzle/0118_joe_fraud_review.sql`, following the shape of
`0021_second_pass.sql`. All additive, all defaulted, no backfill:

| Column | Type | Purpose |
|---|---|---|
| `joe_project_id` | `text not null default ''` | UUID Joe returned from `POST /projects` |
| `joe_submitted_at` | `timestamptz` | When we successfully submitted |
| `joe_trust_score` | `integer` | 1 to 10, from the outcome |
| `joe_outcome` | `text not null default ''` | `approved` or `rejected` |
| `joe_reason` | `text not null default ''` | Rejection reason, empty when approved |
| `joe_reviewed_at` | `timestamptz` | Joe's `outcome.reviewedAt` |
| `joe_reviewer` | `text not null default ''` | Joe's `outcome.reviewerName` |
| `joe_error` | `text not null default ''` | Last submission failure, for display and retry |

Per the `migration-files-drifted` note, production is the source of truth: run
this against production directly rather than assuming `db:migrate` rebuilds
state.

`projects.status` is written as a bare string throughout both apps and no check
constraint or enum on it appears in `drizzle/`, so `fraud_review` should need no
type change. The migration files cannot confirm this (see
`migration-files-drifted`: they never described the whole schema), so confirm
against production before writing the transition, and add a constraint value if
one turns out to exist.

## 2. Joe client (`apps/dashboard/lib/joe.ts`)

New file. Owns every call to Joe and the enabled check. Nothing else in the
codebase constructs a Joe request.

```
joeEnabled(): boolean
submitProject(projectId: number): Promise<{ ok: boolean; error?: string }>
fetchProjects(): Promise<JoeProject[]>
```

Config, all read from the environment:

- `JOE_API_BASE`, defaulting to `https://joe.fraud.hackclub.com/api/v1/ysws`
- `JOE_EVENT_ID`
- `JOE_API_KEY`
- `JOE_WEBHOOK_SECRET`

`submitProject` reads the project and its owner, then POSTs to
`/events/{eventId}/projects`:

- `name` from `projects.name`
- `codeLink` from `repo_url`, `demoLink` from `demo_url` (omitted when empty)
- `submitter`: `{ slackId }` when the owner has one, otherwise `{ email }`.
  Exactly one key, as the API requires.
- `hackatimeProjects` from `projects.hackatime_projects`
- `organizerPlatformId`: `pixl-<projectId>-<shipped_at as unix seconds>`

The `organizerPlatformId` choice matters. `apps/server/src/routes/projects.ts`
refreshes `shipped_at` on every ship, so a re-shipped project produces a fresh
Joe record instead of colliding with its previous one, while a retried POST
within the same ship deduplicates to Joe's 200 response. On a 200 or 201 we store
`joe_project_id` and `joe_submitted_at` and clear `joe_error`; on anything else
we store the status and body in `joe_error` and leave `joe_project_id` empty,
which is what the cron retries on.

A submitter with neither a `slack_id` nor an `email` cannot be submitted. That
is recorded in `joe_error` like any other failure and surfaces to a final
reviewer as a force-advance candidate.

All requests carry `AbortSignal.timeout(10000)` and never throw, matching the
pattern in `lib/ysws.ts` and `lib/notify.ts`.

## 3. Pass 1 transition (`apps/dashboard/app/actions.ts`)

In the `stage === "shipped" && verdict !== "needs_changes"` branch, the status
written becomes `joeEnabled() ? "fraud_review" : "second_review"`.

After the update succeeds and the existing audit, payout and mod-log calls run,
fire `submitProject(projectId)`. **The submission never blocks the transition.**
If it fails, the project still sits in `fraud_review` with `joe_error` set and
the cron retries it. A network blip must not strand a reviewer mid-verdict or
leave the project in a status that does not match what we told Joe.

`nextReviewPath` is called as before. It needs no change: `nextReviewId` selects
from explicit status lists (`shipped`, `second_review`), so `fraud_review` is
excluded by construction.

## 4. Receiving the outcome

Two independent paths, because Joe's webhook is fire-and-forget with no retries.

### Webhook

`apps/dashboard/app/api/joe/outcome/route.ts`, a `POST` handler.

Joe sends no authentication header, only `Content-Type: application/json`, so
the shared secret rides in the query string: the registered URL is
`https://<dashboard>/api/joe/outcome?key=<JOE_WEBHOOK_SECRET>`. A mismatched or
missing key returns 401. An unset `JOE_WEBHOOK_SECRET` returns 500 rather than
accepting unauthenticated writes.

The handler ignores any `event` other than `outcome.set`, resolves the project by
`joe_project_id`, and writes `joe_trust_score`, `joe_outcome`, `joe_reason`,
`joe_reviewed_at` and `joe_reviewer`.

It is idempotent on `projectId`, as the docs require. The status transition to
`second_review` happens **only** when the project is currently in
`fraud_review`. A project already at `second_review`, `approved` or banned gets
its Joe fields refreshed and is not moved, so a replayed or overwritten webhook
cannot drag a decided project backwards.

It returns 200 quickly and does all of the above before responding, since there
is no retry to fall back on. Failures are logged, never thrown.

### Cron

`apps/dashboard/app/api/cron/joe-sync/route.ts`, registered in
`apps/dashboard/vercel.json` at `0 * * * *`, using the same `CRON_SECRET` bearer
check as `queue-health`.

Two jobs per run:

1. **Retry submissions.** Every project in `fraud_review` with an empty
   `joe_project_id` goes back through `submitProject`.
2. **Reconcile outcomes.** `GET /events/{eventId}/projects` once, then for every
   project in `fraud_review` with a `joe_project_id`, match on Joe's `id` and
   apply any `outcome` present using the same write-and-transition logic as the
   webhook. This is what recovers a dropped webhook delivery.

The shared write path is a single exported function used by both the webhook and
the cron, so there is one definition of "what an outcome does" rather than two
that can drift.

### Registering the webhook URL

A one-time `PATCH /events/{eventId}` with `outcomeWebhookUrl`. Documented as a
curl in `apps/dashboard/.env.example` next to the Joe variables rather than
automated, since it runs once per environment.

## 5. Reviewer-facing dashboard

`fraud_review` is **not actionable by anyone.** No verdict form, no claim, no
appearance in the working queue.

- `app/_components/ProjectBadges.tsx`: add
  `fraud_review: { label: "Fraud review", tone: "blue", dot: "bg-blue-500" }`.
- `lib/db.ts`: add `listFraudReviewProjects(viewer?)`, mirroring
  `listSecondReviewProjects` but filtered to `fraud_review` and ordered by
  `joe_submitted_at`. `countPendingReviews` and `nextReviewId` are left alone;
  both already enumerate statuses explicitly.
- `app/review/page.tsx`: a read-only "Waiting on fraud review" list, visible to
  final reviewers only, showing how long each project has been waiting and
  whether it reached Joe at all.
- `app/review/[id]/page.tsx`: a Joe panel showing trust score, outcome, reason,
  reviewer and timestamps, or `joe_error` when submission failed. On a
  `second_review` project whose `joe_outcome` is `rejected`, a red banner above
  the verdict form. It states the fraud rejection and its reason, and does not
  disable any control. The final reviewer still decides.
- `app/api/cron/queue-health/route.ts`: include a stuck-in-fraud count, so a
  backlog is visible in the daily Slack alert rather than silent.

### Force-advance

A final reviewer can push a stuck project from `fraud_review` to `second_review`
by hand. New server action in `actions.ts`, gated on `access.canSecondPass`,
requiring a non-empty reason, guarded with `.eq("status", "fraud_review")` on the
update, and logged via `logModAction` as `project_fraud_override`. This is the
escape hatch for a project Joe never scores, or one that could not be submitted
at all.

## 6. Player-facing

Players see `fraud_review` as plain "In review". The fraud stage is never named
to them.

Every place that currently lists `shipped` and `second_review` together needs
`fraud_review` added, otherwise projects silently become uneditable or drop out
of Trial counts mid-review:

- `apps/server/src/routes/sidequests.ts:35` (Trial progress counting)
- `apps/server/src/routes/projects.ts:559` (edit-while-in-review guard)
- `apps/server/src/routes/projects.ts:665` (timeline events)
- `apps/dashboard/lib/db.ts:517` (`notifyReviewStarted` status guard)
- `apps/game/scripts/first_project_guide.gd:169`
- `apps/game/web/projects/index.html:1806`

No new player notification fires when a project enters or leaves the fraud
stage. From the player's side the project simply stays in review.

## 7. Environment

Added to `apps/dashboard/.env.example`:

```
JOE_API_BASE=https://joe.fraud.hackclub.com/api/v1/ysws
JOE_EVENT_ID=
JOE_API_KEY=
JOE_WEBHOOK_SECRET=
```

`JOE_EVENT_ID` and `JOE_API_KEY` must come from Hack Club. The feature can be
built and merged without them; the kill switch keeps the current two-pass
behaviour until they are set.

## Verification

There is no test suite in this repo, so verification is manual and must be
reported honestly, per `verification-before-completion`:

- `bun run --cwd apps/dashboard typecheck`
- A local script posting both an `approved` and a `rejected` webhook payload
  against a running dev server, checking the status transition and the stored
  fields, plus a replay of the same payload to confirm idempotency.
- A webhook post against a project already in `second_review`, confirming the
  status does not move backwards.
- A cron dry-run against the live Joe list endpoint, if credentials are
  available. If they are not, this step is reported as not run rather than
  assumed working.

## Out of scope

- Renaming `second_review` to `final_review`.
- Calling `POST /review` or `POST /outcome` on Joe.
- Hardware submissions (`isHardware`, `hardwareJournal`). Pixl is a
  Hackatime-type software event.
- Pagination of Joe's list endpoint. It returns all projects in one response;
  revisit if Pixl's event grows large enough to matter.
