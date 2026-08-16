/**
 * Bakes the `npcs` table into apps/game/npcs.json, the client's offline
 * fallback.
 *
 *   DATABASE_URL=... bun run npcs:bake
 *
 * multiplayer_world.gd fetches /api/npcs first and only reads this file when
 * that can't be trusted (signed out, offline, server error). Re-run it after
 * changing NPCs in the dashboard, otherwise an offline player sees the world as
 * it was at the last bake.
 *
 * Trial names mirror the API exactly: an NPC whose Trial is missing or inactive
 * bakes an empty trial_name, so it falls through to flavor text rather than
 * offering a quest the server would reject.
 */
import { writeFile } from "node:fs/promises";
import { join } from "node:path";
import postgres from "postgres";

const DATABASE_URL = process.env.DATABASE_URL;
if (!DATABASE_URL) throw new Error("DATABASE_URL must be set");

const OUT = join(import.meta.dirname, "..", "..", "..", "game", "npcs.json");

const sql = postgres(DATABASE_URL, { max: 1, onnotice: () => {} });

const rows = await sql<Record<string, unknown>[]>`
  select n.world, n.pos_x, n.pos_y, n.npc_name, n.skin, n.custom_hair, n.custom_sheet,
         n.dialogue, n.opens_projects, n.opens_explore, n.quest_project, n.faq,
         n.quest_trial, n.trial_checkin, n.quest_offer, n.quest_done, n.trial_reminder,
         n.wanders, n.speed, n.wander_radius, n.min_wait, n.max_wait,
         case when s.active then s.name else '' end as trial_name
  from npcs n
  left join sidequests s on s.id = n.sidequest_id
  where n.active = true
  order by n.world, n.sort_order, n.id`;

const byWorld: Record<string, Record<string, unknown>[]> = {};
for (const r of rows) {
  const { world, ...rest } = r as Record<string, unknown> & { world: string };
  (byWorld[world] ??= []).push({ ...rest, trial_name: rest.trial_name ?? "" });
}

await writeFile(OUT, `${JSON.stringify(byWorld, null, "\t")}\n`);
const counts = Object.entries(byWorld).map(([w, v]) => `${w}=${v.length}`).join(" ");
console.log(`baked ${rows.length} NPCs -> ${OUT} (${counts})`);

await sql.end();
