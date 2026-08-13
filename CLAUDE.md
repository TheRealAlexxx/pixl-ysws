# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository overview

Pixl is a Bun/Turborepo monorepo (`bun` workspaces: `apps/*`, `packages/*`) for a Hack Club YSWS ("You Ship, We Ship") pixel-art multiplayer game.

| App | Stack | Purpose |
|---|---|---|
| `apps/server` | Bun, Express, `ws`, Drizzle ORM, Supabase (Postgres) | Game server — auth, player state, WebSocket game/lobby logic, projects, shop, economy |
| `apps/game` | Godot 4 | The 2D multiplayer game client (not TypeScript — GDScript/Godot project) |
| `apps/landing` | Next.js 16, React 19, Tailwind 4 | Marketing site (pixl.rsvp) |
| `apps/dashboard` | Next.js 16, React 19, Tailwind 4, shadcn/radix, Supabase | Admin/review dashboard — moderation, tickets, review queue, stats |
| `apps/pixorpheus` | Bun, TypeScript, Slack Bolt v4, Express, Supabase | Slack bot — tickets, AI chat, moderation DMs, slash commands |
| `packages/config` | JSON + plain ESM | **Single source of truth** for the program's facts — name, launch date, Hackatime cutoff, canonical URLs, economy rates. See below. |
| `packages/*` (`types`, `ui`, `utils`) | — | Currently scaffolded but empty; intended for shared code across apps |

Each app has its own `package.json`/scripts and is largely independent; they share only Supabase as a common data layer (each app talks to Supabase directly rather than through a shared internal API), plus Hack Club Auth/Slack OAuth for identity.

## Commands

Run from the repo root unless noted. This repo uses Bun — see the Bun-specific guidance below.

```bash
bun install                                  # install all workspaces

# Turborepo shortcuts (root package.json)
bun run dev                                  # run all apps' dev servers concurrently
bun run landing                              # turbo dev --filter=@pixl/landing
bun run dashboard                             # turbo dev --filter=@pixl/dashboard
bun run build                                # turbo build (all apps)

# Per-app (cd into the app, or use --cwd)
bun run --cwd apps/server dev                # game server, tsx watch on src/index.ts
bun run --cwd apps/server build              # tsc build to dist/
bun run --cwd apps/server db:generate        # drizzle-kit generate (schema -> migration)
bun run --cwd apps/server db:migrate         # drizzle-kit migrate
bun run --cwd apps/server db:studio          # drizzle-kit studio

bun run --cwd apps/landing dev               # next dev
bun run --cwd apps/dashboard dev    # next dev -p 4900
bun run --cwd apps/dashboard typecheck  # tsc --noEmit

bun run --cwd apps/pixorpheus start          # Slack bot (src/index.ts), Bun-native, no build step
bun run --cwd apps/pixorpheus dev            # same, with --watch
bun run --cwd apps/pixorpheus typecheck      # tsc --noEmit
```

There is no root-level test suite; `apps/pixorpheus`'s `test` script is a placeholder. Check an individual app's `package.json` before assuming a script (lint/typecheck/test) exists there.

### Environment

Each app has its own `.env` (see `.env.example` where present, e.g. `apps/server/.env.example`). Bun auto-loads `.env` files — don't add `dotenv` to Bun-run apps (note `apps/server` still imports `dotenv/config` itself in some files; follow existing conventions in that file rather than changing it unprompted — `apps/pixorpheus` relies on Bun's auto-load and has no `dotenv` dependency). Common vars: `SUPABASE_URL` / `SUPABASE_SERVICE_KEY` (shared across apps), `JWT_SECRET`, Hack Club Auth (`HCA_CLIENT_ID`/`SECRET`/`REDIRECT_URI`), Slack tokens for `pixorpheus`/`dashboard`.

### `packages/config` (shared program facts)

Never hardcode the launch date, the Hackatime cutoff, a pixl.rsvp URL or the
economy rates in an app — they all live in `packages/config/pixl.json`.

- Nothing imports `@pixl/config` at runtime, not even the TS apps — Railway/Vercel build each app from its own `/apps/<app>` root, so a workspace package outside that root doesn't resolve there. Every consumer instead reads a **generated, git-committed copy** produced by `bun run config:sync` after you edit `pixl.json` — never hand-edit the generated files, the next sync overwrites them.
- **TS apps**: `server`/`pixorpheus` import `../config.generated.js` (the `.js` extension is required — they run as ESM); `landing`/`dashboard` import `../_generated/config` (or the `@/app/_generated/config` alias) — all expose `config`, `launchDate`, `hackatimeCutoffUnix`, `hasLaunched`, `launchDateLabel`, etc.
- **Godot** (`apps/game/scripts/pixl_config.gd`) reads `apps/game/pixl.json`, and **the game's web pages** read `Pixl.config` in `apps/game/web/pixl.js` — both are also generated copies from the same sync.
- Dates are ISO-8601 **UTC**. Format them with `timeZone: "UTC"`; a naive `new Date("2026-08-18T00:00:00")` means midnight in the *reader's* timezone and is the exact drift this package exists to stop.

Launch-state copy (Pixo's persona/FAQ, the Slack welcome messages) switches itself
via `hasLaunched()` — there is no string to flip on launch day.

## Architecture notes

### `apps/server` (game server)
- Entry point `src/index.ts`; Express HTTP routes live under `src/routes/*` (auth, profile, projects, shop, sidequests, story, friends, explore, admin, reports, hackatime, vault, notifications, uploads, events).
- Real-time game state is handled separately in `src/ws/gameServer.ts` (the authoritative multiplayer/WebSocket loop) and `src/ws/lobbies.ts` (private village / lobby grouping).
- `src/auth/session.ts` issues/validates JWT sessions signed with `JWT_SECRET`; Hack Club Auth (HCA) is the identity provider.
- `src/db/client.ts` + `src/db/schema.ts` (Drizzle) define the Postgres schema (via Supabase). Run `db:generate` after schema changes, then `db:migrate` to apply.
- Cross-cutting concerns: `src/xp.ts` (leveling/XP), `src/moderation.ts` / `src/imageModeration.ts` (content moderation, ties into `dashboard`'s review queue), `src/rateLimit.ts`, `src/hackatime/api.ts` (coding-time tracking integration), `src/shipsArchive.ts` (project submission history).

### `apps/game` (Godot client)
- Not a Node/Bun project — it's a Godot 4 project (`project.godot`, `scenes/`, `scripts/`, `addons/`, `shaders/`). GDScript, not TypeScript. Don't try to `bun install`/run it like the other apps.
- `web/` holds the web export target; `exports/` and `build/` hold build artifacts (gitignored).
- The minimap and world map draw a **baked** top-down PNG of each world (`assets/map/*.png` + `bounds.json`), produced by `scripts/tools/world_map_baker.gd`. Re-bake after moving tilemaps: open `scripts/tools/bake_world_map.gd` in the editor and hit File > Run, or `godot --script scripts/tools/bake_world_map_cli.gd` (needs a real display — `--headless` bakes black). If the PNGs are missing both maps fall back to a flat placeholder rect.

### `apps/landing` and `apps/dashboard` (Next.js)
- Both run **Next.js 16** with React 19 and Tailwind 4 (very recent — training-data knowledge of Next.js APIs/conventions is likely stale). `apps/landing` has an `AGENTS.md` flagging this explicitly: **read the relevant guide in `node_modules/next/dist/docs/` before writing Next.js code in either app**, and heed deprecation notices.
- `dashboard` runs on port 4900 (`next dev -p 4900` / `next start -p 4900`) since multiple apps run concurrently in dev. It uses shadcn/radix-ui components and talks to Supabase directly plus Slack OAuth (`app/api/auth/*`) for admin login.
- Page routes follow Next App Router conventions (`app/<route>/page.tsx`); shared page-local components live in `app/_components/`.

### `apps/pixorpheus` (Slack bot)
- Bun-native TypeScript, no build step (`bun run src/index.ts`) — a single Bolt v4 process, organized by feature under `src/` (`tickets/`, `chat/`, `ai/`, `memory/`, `commands/`, `pixelate/`, `github/`, `external/`, `slack/`). There is no separate dashboard process anymore — helper/admin ticket moderation lives in `apps/dashboard` (the Next.js app), which resolves tickets through `src/external/ticketApi.ts` on this bot.
- `models.json` lists OpenRouter models available to the AI chat/roast/fact features.
- See `apps/pixorpheus/README.md` for the full slash-command reference and architecture table before modifying bot behavior.

## Bun usage

Default to Bun over Node.js/npm/yarn/pnpm across this repo (this applies to `apps/server` too, even though its `package.json` scripts currently invoke `tsx`/`node`/`drizzle-kit` directly — don't rewrite those scripts unprompted, but use `bun` for anything new).

- `bun <file>` instead of `node <file>` or `ts-node <file>`
- `bun test` instead of `jest`/`vitest`
- `bun build <file>` instead of `webpack`/`esbuild`
- `bun install` instead of `npm`/`yarn`/`pnpm install`
- `bun run <script>` instead of `npm run`/`yarn run`/`pnpm run`
- `bunx <package>` instead of `npx <package>`
- Bun auto-loads `.env` — don't add `dotenv` to new Bun code.
- `Bun.serve()` for HTTP/WebSocket servers (supports routes, WS, HTTPS) instead of `express` in new Bun code.
- `bun:sqlite` instead of `better-sqlite3`; `Bun.redis` instead of `ioredis`; `Bun.sql` instead of `pg`/`postgres.js`; built-in `WebSocket` instead of `ws`.
- `Bun.file` over `node:fs` readFile/writeFile.
- `Bun.$\`cmd\`` instead of `execa`.

For HTML-import-based frontends (not used by the Next.js apps here, but the default for any new Bun frontend): `Bun.serve()` serving an `index.html` that `<script type="module" src="./frontend.tsx">`s a React entrypoint — no Vite. See `node_modules/bun-types/docs/**.mdx` for the full Bun API reference.
