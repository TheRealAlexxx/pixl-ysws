# Projects page redesign

Rework `apps/game/web/projects/index.html` into a dashboard-style page modelled on
Beest's `/home`, and point the village HOME door at the existing Overview page.

Reference layout supplied by the user: left sidebar (Pixl already has one), a big
title, a hours progress bar with a threshold, a status legend, wide banner project
cards, a centered action row, and two bottom panels (action log and news).

## Decisions

Taken from the brainstorming session, recorded so implementation does not
re-litigate them:

- No countdown panel. Beest counts down to its launch; Pixl's launch state is
  already handled by `hasLaunched()` elsewhere.
- The hours bar tracks the player's active Trial against that Trial's
  `min_hours`, not a lifetime qualification threshold. Pixl pays per project by
  tier, so Beest's "40h to qualify" framing has no equivalent.
- News gets a real table plus an authoring page in `apps/dashboard`, not a
  git-committed JSON file.
- The action log is synthesized from tables that already exist rather than a new
  append-only log table, so it backfills for current players instead of starting
  empty for everyone.
- The village HOME door opens the existing `/dashboard` Overview page. The house
  interior is dropped.

## Scope

Four areas change: the projects web page, the game server, the admin dashboard,
and the Godot village scene.

## 1. Projects page (`apps/game/web/projects/index.html`)

The editor, project detail, ship flow, collaborator and YSWS-import views are
untouched. Only the hero and `renderList()` are reworked, plus two new panels
below the list. New CSS goes in the page's existing `<style>` block, reusing the
shell tokens from `web/pixl.css` (`--gold`, `--panel`, `.card`, `.chip`, `.rbar`).

### Header

Existing `.hero` keeps the title and subtitle. A status legend is added on the
right: a colored dot, a label, and a count for Approved, In review, Needs
changes, and Draft. Colors come from the classes `statusInfo()` already returns,
so the legend cannot drift from the chips on the cards.

### Trial hours bar

Below the header, full width:

- Left: hours logged, large, in the pixel face (for example `6.1H`).
- Right: `12H TO SHIP`, from the active Trial's `min_hours`.
- Under both: a `.rbar` fill with tick labels at 0, a quarter, a half, three
  quarters, and the target.

The active Trial is picked from the `trials` array (Trials the player has
accepted and not finished, already loaded from `/api/sidequests`) in this order:
the first Trial that has a project linked to it via `sidequest_id`, otherwise the
first Trial in the array. Hours come from `linkedSeconds()` on the linked
project, or zero when the chosen Trial has no project yet.

With no active Trial the bar falls back to total tracked Hackatime hours with no
threshold and no target label.

`min_hours` is enforced today by the ship gate in `apps/server/src/routes/projects.ts`
(around line 456) but is not selected by `GET /api/sidequests`. Add it to that
select.

### Project cards

Replaces the current thin `.proj-row` list. Per card:

- Wide banner thumbnail on the left, roughly 4:1, from `image_url`. Falls back to
  an empty slot when absent, matching the current `onerror` behaviour.
- Name, then tier chip (`LEVELS[level - 1][0]`), then status chip.
- Description under the head, clamped to two lines.
- A link row: CODE (`repo_url`), DEMO (`demo_url`), the linked Hackatime project
  names, hours coded, and pixels earned when non-zero.
- Existing `needs_changes` and rejection note strips are preserved.

Structural change: the card is currently a single `<a>` wrapping the whole row,
and anchors cannot nest, so real repo and demo links cannot live inside it. The
card becomes a `<div class="card panel">` with the project name as the
`href="#p=<id>"` link and a right-side chevron as a second link to the same
place. Hash routing is unchanged.

### Action row

`+ NEW PROJECT` and `SHIPPING GUIDE` centered under the cards. The guide points
at the existing `/docs/shipping` page.

The empty state keeps its current copy and its single call to action.

### Action log panel

Bottom left. Reads `GET /api/activity`. Renders up to 12 entries, each a colored
dot, a line of text, and a relative timestamp from `Pixl.timeAgo()`. Dot color is
keyed off the entry kind. Panel hides itself when the list is empty.

### News panel

Bottom right. Reads `GET /api/news`. Each entry is a short date on the left and
the body on the right, with the body linked when `link_url` is set. Panel hides
itself when there are no posts, so it never renders as an empty box.

Both panels sit in a two-column grid that collapses to one column on narrow
viewports.

## 2. Server (`apps/server`)

### `GET /api/activity`

New route file `src/routes/activity.ts`, registered in `src/index.ts` alongside
the others. Session token auth, matching the other player routes.

Merges these sources for the signed-in user, sorts newest first, caps at 12, and
returns `{ ok: true, activity: [{ kind, text, at }] }`:

- `projects`: created, shipped, approved, rejected, and needs-changes timestamps.
- `project_journals`: an entry logged against a project.
- `pixel_transactions`: pixels earned or spent, with the project name attached
  the same way `GET /api/profile/transactions` already does it.
- `sidequest_unlocks`: a Trial accepted.

Column names are confirmed against the live schema during implementation. Any
source whose columns turn out not to exist is dropped rather than faked.

### `GET /api/news`

Public, no auth, since the news panel shows the same posts to everyone. Returns
active rows ordered by `posted_at` descending, capped at 20.

### Migration `drizzle/0117_news.sql`

```sql
create table if not exists news (
  id bigserial primary key,
  body text not null,
  link_url text,
  posted_at timestamptz not null default now(),
  active boolean not null default true
);
create index if not exists news_posted_at_idx on news (posted_at desc);
```

The migration file is written but not applied. Prod is the source of truth for
this database and the migration files cannot rebuild it, so the table is created
against Orchard Postgres deliberately and separately, before the code that reads
it deploys.

## 3. Dashboard (`apps/dashboard`)

A `/news` authoring page built on the same pattern as
`app/community-goals/page.tsx`: a server component, an add form, one form per
existing row, and hide and delete actions.

- `lib/guard.ts`: add `"news"` to `ALL_PERMISSIONS`. No migration needed, since
  permissions live in an `admins.permissions` text array and supers get every
  permission automatically.
- `lib/db.ts`: `listNews`, `addNews`, `updateNews`, `toggleNews`, `deleteNews`,
  plus a `NewsRow` type.
- `app/actions.ts`: server actions wrapping those, each gated by
  `requirePerm("news")`, redirecting back with `?saved=1` or `?error=`.
- `app/news/page.tsx`: gated by `requirePagePerm(["news"])`, using `Card`,
  `Input`, `Textarea`, `Label`, and `PendingButton`.
- `app/_components/Shell.tsx`: nav entry, icon, and the `news` flag on the nav
  permissions object.

## 4. Godot (`apps/game`)

- `scenes/village.tscn`: the HOME `DoorTrigger` (around line 2641) gets
  `target = "dashboard"`. It currently has no target, so it falls through to the
  default branch.
- `scripts/village.gd`: handle `"dashboard"` with `WebPages.open("dashboard")`,
  next to the existing `"shop"` case.
- The default branch that loads `house_interior.tscn` becomes dead code, since
  the HOME door was the only untargeted door in the village and `village.gd` is
  the only place in the codebase that loads that scene. The branch is removed
  along with the `house_variant` computation that feeds it.
- `scenes/house_interior.tscn` and its script stay in the repo, unreferenced, so
  the work is easy to reverse. This is stated plainly rather than quietly left
  behind.

`WebPages.open()` already appends the session token and `embed=1`, so the
Overview page authenticates the same way the shop does today.

## Testing

There is no test suite in this repo, so verification is manual and stated
honestly rather than implied:

- `bun run --cwd apps/dashboard typecheck` must pass.
- `bun run --cwd apps/server build` must pass.
- The projects page is loaded in a browser against a local server, checked in
  both themes and at a narrow viewport, with at least these states: no projects,
  a project with no thumbnail, a project with no repo or demo, an active Trial,
  no active Trial, Hackatime not connected, and both bottom panels empty.
- The two new endpoints are hit directly and their shapes confirmed before the
  page is wired to them.
- The Godot change is verified by walking to the HOME door and pressing E.

## Out of scope

- Any change to the editor, ship flow, review flow, or payout logic.
- Applying the migration to production.
- Backfilling news posts.
- Reconciling the overlap between the redesigned projects page and the existing
  `/dashboard` Overview page. Both stay as they are.
