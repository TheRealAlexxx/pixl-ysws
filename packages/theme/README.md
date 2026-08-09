# @pixl/theme

`palette.json` is the one place DUSK (and light mode) live as data: the named
color tokens, dark and light. Change a value here and every consumer that
generates off it picks it up.

## Two value sets, one vocabulary

`palette.json` has `web` and `godot` top-level keys, each with `dark`/`light`
theme objects using the same token names (`ink`, `gold`, `panel`, ...). The
values are **not** forced to match between the two: `apps/game/web/pixl.css`
and `apps/game/themes/main_theme.tres` were designed independently and were
never pixel-identical, so unifying the literal hex values would be a visual
change, not plumbing. What's shared on purpose is the token vocabulary and the
dark/light switching mechanism, not (yet) the exact hues. Making the game and
the web shell actually share the same gold is a deliberate future design
pass, not this one.

`godot.light` does not exist. The game has no light-mode design yet.
`PixlTheme` (`apps/game/scripts/pixl_theme.gd`) falls back to `godot.dark`
whenever a synced "light" choice reaches the game, so a player who picked
light on the web shell still sees DUSK in-game, unchanged, until someone
designs a Godot light variant.

`web.dark.effects` / `web.light.effects` (`drop`, `dropLg`, `dither`) are
literal CSS value strings, not derived from `ink` — the shadow/dither rgba
values were hand-tuned per theme and don't reduce to a clean tint of `ink`.
Godot has no consumer for these, so they're omitted from the generated
`apps/game/theme.json`.

`--img-slot` in `pixl.css` stays out of this file entirely — it's explicitly
fixed, never redefined per theme (see the comment next to it in `pixl.css`).

## Consuming it

Nothing imports `@pixl/theme` at runtime, for the same reason nothing imports
`@pixl/config` at runtime: Railway/Vercel build from per-app roots, and the
game runs from an exported PCK. Generated, committed copies reach every
consumer instead:

```bash
bun run theme:sync
```

Run that after editing `palette.json`. It rewrites:

- `apps/game/theme.json` — read by `apps/game/scripts/pixl_theme.gd`
- the color-token lines inside `apps/game/web/pixl.css`'s `:root{}` and
  `:root[data-theme="light"]{}` blocks, between `/* <pixl-theme:...> */`
  markers. Everything else in those blocks (the DUSK design-philosophy
  comment, `--img-slot`, structural vars like `--sans`/`--radius`/`--notch`)
  is hand-authored and untouched by the sync.

Both are committed (the game and the web shell need them at runtime) but are
**generated — do not hand-edit them**, the next sync overwrites your changes.
