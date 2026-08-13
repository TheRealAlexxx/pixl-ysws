-- Two content changes to Dustline Trials:
--
-- 1. "Claim Your Stake" (Ridit, the starter Trial every new player gets right
--    after onboarding) used to read as a build brief ("Create a project, give
--    it a proper name, keep a journal of your work, and ship it."). That's
--    redundant with the in-game "YOUR FIRST TRIAL" tracker/ship picker, which
--    already walks the player through meet -> create -> hackatime -> build ->
--    ship. Reworded to a plain onboarding check-in beat instead of an
--    assignment.
--
-- 2. New HARDWARE Trial, "A Song That Doesn't Need a Wire" (Birdie), same
--    tier/reward shape as Rill's "How Deep Is It": Soldering Iron Kit +
--    Hardware Grant. A custom MP3 player, in keeping with the Dustline's
--    "nothing plugged into the Core" rule (see dustline-region-canon).
--
-- Run this in the Supabase SQL editor. Safe to run more than once.

UPDATE sidequests
SET description = 'Every pioneer stakes a claim somehow, whatever that looks like for you. Ridit''s kept an eye out since you got here, not to rush you or point you anywhere in particular, just to see how the frontier''s treating you so far.'
WHERE name = 'Claim Your Stake';

INSERT INTO sidequests (name, region, npc, description, reward, difficulty, tags, min_hours, starter, active, position)
SELECT v.name, v.region, v.npc, v.description, v.reward, v.difficulty, v.tags, v.min_hours, false, true, v.position
FROM (VALUES
  ('A Song That Doesn''t Need a Wire', 'Dustline', 'Birdie',
   'Build a music player: load your own songs onto it and play them back through real speakers. No antenna, no signal, no app, just buttons for play, pause, skip, and volume. Battery has to last a full night at the saloon. (Minimum 15h of tracked work.)',
   'Soldering Iron Kit + Hardware Grant', 2::smallint, ARRAY['hardware']::text[], 15, 7)
) AS v(name, region, npc, description, reward, difficulty, tags, min_hours, position)
WHERE NOT EXISTS (
  SELECT 1 FROM sidequests s WHERE s.name = v.name
);
