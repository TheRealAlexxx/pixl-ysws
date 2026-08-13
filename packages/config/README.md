# @pixl/config

`pixl.json` is the one place the program's facts live: the name, the launch date,
the canonical URLs, the Slack channel, the economy rates. Change it here and
every app picks it up.

## Consuming it

Nothing imports `@pixl/config` at runtime - not even the TypeScript apps.
Railway and Vercel both build each app from its own `/apps/<app>` root, so a
workspace package living outside that directory doesn't exist at install
time there. Every consumer instead gets a *generated, committed copy*,
written by the sync script:

```bash
bun run config:sync
```

Run that after editing `pixl.json`. It rewrites:

- `apps/game/pixl.json` - read by `apps/game/scripts/pixl_config.gd`
- the generated block inside `apps/game/web/pixl.js` - exposed as `Pixl.config`
- `apps/server/src/config.generated.ts`
- `apps/pixorpheus/src/config.generated.ts`
- `apps/landing/app/_generated/config.ts`
- `apps/dashboard/app/_generated/config.ts`

**TypeScript apps** import their own generated copy by relative path, e.g.:

```ts
// server / pixorpheus (compiled/run as ESM, so the .js extension is required)
import { config, launchDate, hackatimeCutoffUnix } from "../config.generated.js";

// landing / dashboard (Next.js, no extension)
import { config, launchDate } from "../_generated/config";
// or, using the app's path alias: from "@/app/_generated/config"
```

All of these files are committed (the apps need them to build and run) but are
**generated - do not hand-edit them**, the next sync overwrites your changes.

## Dates

Every timestamp here is UTC and ISO-8601. Parse it as an instant, not a local
wall-clock time - `new Date("2026-08-18T00:00:00")` without the `Z` means
midnight *in the reader's timezone*, which is a different moment for every
player and is exactly the bug this file exists to prevent.

`hackatimeCutoff` is deliberately its own field rather than an alias for
`launchDate`: it is the moment coding time starts counting toward shipping, and
there are good reasons to want it to differ from the launch moment later.
