# Trial-giver teleport: open world <-> village

## Problem

A Trial-giver NPC (Ridit, Wren, Rill, Cass) currently just sits in `open_world.tscn` forever, whether or not you've accepted their Trial. Separately, `village.tscn` already has a hidden "check-in" copy pattern (built for Ridit, generic fallback for anyone else) that reveals itself once a Trial is accepted and hides itself once it's completed - but only checked on scene load, with no visual flourish, and nothing ever hides the *original* open-world giver. The player never gets the "they moved to the village to help me" read.

## Goal

Accepting a Trial visibly relocates its giver from the open world to the village (with a teleport effect), and finishing it visibly relocates them back. Applies uniformly to all 4 Dustline givers (Ridit, Wren, Rill, Cass) via the same shared mechanism.

## Mechanism

### Teleport FX
New `npc.gd` method `_play_teleport_fx()`: builds a one-shot `CPUParticles2D` pixel-dust burst (small square motes, additive blend, quick radial burst + fade) at the NPC's current position, in code, no new scene file - same runtime-construction pattern already used by `night_ambience.gd`. Auto-frees after the burst finishes.

### Live accept moment
In `npc.gd._start_trial_quest()`, in the `"accept"` branch, right after `await _accept_trial(tid)` succeeds: call `_play_teleport_fx()` on `self`, briefly wait for the burst to read, then `set_present(false)`. The player watches the open-world giver they're standing in front of vanish. This only runs on non-checkin givers (checkin copies never reach the accept branch).

### One-time transition tracking
Trial completion happens async (a reviewer approves on the dashboard, not a live in-game moment), so there's no live trigger for "just finished." Scene-load polling (`village.gd`'s existing `_reveal_trial_npcs`, and a new equivalent in `open_world.gd`) is the only place to catch it - but polling naively on every scene load would replay the fx every single visit, forever, which reads as broken rather than special.

New helper `apps/game/scripts/trial_fx_state.gd`, backed by a `ConfigFile` at `user://trial_fx_seen.cfg`:
- Sectioned by `NetworkManager.user_id`, so multiple accounts on the same device never share state.
- Keyed by trial name, value is last-known state string: `"none"` / `"active"` / `"completed"`.
- `TrialFx.has_changed(trial_name: String, current_state: String) -> bool`: compares the stored value to `current_state`, persists `current_state` regardless, and returns `true` only when they differed (i.e. a genuine transition happened since the last time this device checked).

Both scenes' sync functions call this before animating, so each side of the teleport fires its fx exactly once per real transition, per account, per device - not on every re-entry.

### `open_world.gd`
New `_sync_trial_givers()`, called from `_ready()`, mirrors the existing village poll: fetches `/api/sidequests`, and for each child NPC with `quest_trial == true`:
- current_state = `"active"` if unlocked && !completed, `"completed"` if completed, else `"none"`.
- if `TrialFx.has_changed(trial_name, current_state)`:
  - `"active"` -> `set_present(false)` silently (no fx here - the live accept moment already played it; this branch exists so a *second* device or a fresh session correctly starts hidden without needing to watch the accept happen).
  - `"completed"` -> stays visible, plays `_play_teleport_fx()` (the "welcome back" flourish).
  - `"none"` -> no-op, matches the scene's default-visible state.
- if unchanged, apply the visibility state silently with no fx (still need to hide it if active, just without the burst).

### `village.gd._reveal_trial_npcs()`
Extended so that whenever a check-in NPC (the hand-authored Ridit copy, or a dynamically-spawned Wren/Rill/Cass copy from `_spawn_dynamic_trial_npcs`) transitions into `"active"` per `TrialFx.has_changed`, it plays `_play_teleport_fx()` right after `set_present(true)`. Hiding on completion stays silent either way (default state is already hidden, nothing to visually animate away from).

## Copy changes

Rewriting each giver's `quest_done` in `open_world.tscn` to a literal good-job line:
- Ridit: "Good job, partner. The frontier's proud of you."
- Wren: "Good job - that draft came together exactly right."
- Rill: "Good job. The well's finally got eyes on it."
- Cass: "Good job. The relay's in good hands now."

## Out of scope

- No server/schema changes - this rides entirely on the existing `unlocked`/`completed` fields from `/api/sidequests`.
- No hand-authored village check-in scenes for Wren/Rill/Cass - they keep using the existing generic `_spawn_dynamic_trial_npcs` fallback, just with the fx layered on.
- Cross-device sync of "already seen" state is not attempted; each device tracks its own local seen-state file.
