# How it works: flow diagram

Replaces the prose cards in the landing's "How it works" section with a single
top-to-bottom flow diagram, in the style of macondo.hackclub.com. The section has
to explain three things to someone who has never heard of Pixl: the build loop,
what chapters are, and how Restoration Energy turns into money.

Note: `docs/superpowers/` is invisible to the docs engine. `packages/docs-engine/build.ts:100`
reads `docs/` non-recursively and keeps only `.md` entries, so this directory
never becomes a player-facing page.

## What changes

| File | Change |
|---|---|
| `apps/landing/app/_components/Flow.tsx` | New. The whole diagram. |
| `apps/landing/app/_components/Story.tsx` | Keeps its heading and countdown, drops the `paths` / `rhythm` / `mechanics` card stacks, renders `<FlowDiagram />` instead. |
| `apps/landing/app/[lang]/dictionaries/*.json` | `story.flow.*` added in all four locales; `story.paths`, `story.rhythm`, `story.mechanics`, `story.andOr` removed. |
| `apps/landing/public/flow-*.{webp,png}` | Three frames pulled from `step-1.mp4` / `step-2.mp4`, two emote sprites copied from the Godot project. |

## The graph

```
                  01 Join the world
                          |
              +-----------+-----------+
        Take a Trial   (and/or)   Build your own
              +-----------+-----------+
                          |
                  02 Ship it  <----------+
                          |              |
                  03 Restoration Energy  | ship another
                     T1 5 / T2 10        |
                     T3 15 / T4 25 per h |
                          +--------------+
                          |
              +-----------+-----------+
        04 You get paid         05 The world comes back
        50 -> 86 px/hr          chapter goal, region unlocks
              +-----------+-----------+
                          |
                   The example ladder
```

Node 05 carries two satellite chips, "Operations" and "Join late", which absorb
the two `rhythm` paragraphs that are not about chapters.

## Numbers

Every figure is computed from `apps/server/src/config.generated.ts` (the generated
copy of `packages/config/pixl.json`), not invented, and pixel prices come from
`ITEM_PRICES` in `Shop.tsx`:

| Build | RE | Payout | Buys |
|---|---|---|---|
| 10h Tier 2 | 100 | 575 px | Blahaj (575) |
| 30h Tier 3 | 450 | 1,975 px | 4K monitor (2,000) |
| 100h Tier 4 | 2,500 | 6,750 px | iPad (6,425) |

Payout is `pxPerHourOver(0, projectRe) * hours + tierKickerUsd(hours, tier) / pixelValueUsd`,
matching `creditBeneficiary` in `apps/dashboard/app/actions.ts`.

The copy states that a project's rate is set by that project's own tier and hours.
It does not say the rate climbs across projects: that stopped being true in
`1a07a43`, when payout scope was fixed from lifetime RE to project RE. Lifetime RE
now only drives level (cosmetic) and the community goal. The FAQ answer at
`dictionaries/en.json` still carries the old claim and is out of scope here.

## Layout and style

One column. Connectors are inline SVG in their own grid rows, so nothing measures
the DOM: a split, a merge, straight verticals, and one dashed loop-back. Below
`sm` the branch pairs stack and the curved connectors swap for straight ones.

Visual language is the section's existing one: 2px black borders, `#fffaf7` cards
on `#F5EED2`, hard offset shadows in `#000` / `#ff8c37` / `#ec3750`, `font-pixel`
titles with `font-sans` body, framer-motion fade-up on scroll with a stagger down
the graph. Screenshots render with `image-rendering: pixelated` because they are
native-resolution 530px pixel art.

Connector SVGs are `aria-hidden`; the graph reads correctly as a linear document
with screen reader images described by their alt text.

## Out of scope

Fixing the same stale rate claim in the FAQ, and the three missing
`/step-{3,4,5}.mp4` files that leave "Coming Soon" overlays in `Description.tsx`.
Both raised with Ridit, both deferred.
