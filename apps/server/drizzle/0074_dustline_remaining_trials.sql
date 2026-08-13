-- Seed the 3 remaining canon Dustline Trials (only Mabel's "The Wall at the
-- Sixteen Colors" existed as a real row before this — Wren/Rill/Cass were
-- documented in lore but never entered into sidequests). Same pattern as
-- 0061/0050: free-text reward, no prize_shop_item_id (ops fulfils by hand,
-- same as Mabel's row), min_hours drives the existing ship/review gate from
-- 0068 automatically since that gate is generic per-sidequest.
--
-- Run this in the Supabase SQL editor. Safe to run more than once.

INSERT INTO sidequests (name, region, npc, description, reward, difficulty, tags, min_hours, starter, active, position)
SELECT v.name, v.region, v.npc, v.description, v.reward, v.difficulty, v.tags, v.min_hours, false, true, v.position
FROM (VALUES
  ('Draw It Before It''s Real', 'Dustline', 'Wren',
   'Draft a region: a map, a tileset, at least 2 NPCs with dialogue, and 1 sidequest hook. Then code a playable demo of it. Art time can''t be more than half your logged hours (11h max on a 22h Trial) — split your time log between art and code. (Minimum 22h of tracked work.)',
   'Graphics Tablet', 2::smallint, ARRAY['game']::text[], 22, 4),
  ('How Deep Is It', 'Dustline', 'Rill',
   'Build a well gauge: one sensor down the shaft, one surface readout, and a low-level warning. It has to run for weeks on battery, survive dust, and work with no laptop tether. (Minimum 12h of tracked work.)',
   'Soldering Iron Kit + Hardware Grant', 2::smallint, ARRAY['hardware']::text[], 12, 5),
  ('Two Hundred Years of Sending', 'Dustline', 'Cass',
   'Build a repeater: two physical devices that pass a message across on radio only — no wifi, no internet, no cloud — with a screen that clicks on arrival. (Minimum 40h of tracked work.)',
   'Flipper Zero', 3::smallint, ARRAY['hardware']::text[], 40, 6)
) AS v(name, region, npc, description, reward, difficulty, tags, min_hours, position)
WHERE NOT EXISTS (
  SELECT 1 FROM sidequests s WHERE s.name = v.name
);
