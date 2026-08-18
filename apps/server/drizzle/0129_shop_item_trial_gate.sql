-- Shop items can be locked behind Trial completion: unlock_trial_ids lists the
-- sidequests that unlock the item. Empty = not gated (buyable as before). When
-- non-empty, the item is locked until the player has SHIPPED (reached review on)
-- a project linked to at least ONE of those Trials — so "do Trial A OR Trial B"
-- unlocks it. The shop route computes `locked` per player and the buy route
-- rejects a locked purchase.
--
-- Seeded use: the Music Grant unlocks by shipping the MP3 Player OR the Jukebox
-- Trial (both music-themed, in the Dustline). Keyed by Trial name for portability.
--
-- Target: the orchard/CNPG database. Idempotent. Run in psql.

ALTER TABLE shop_items
  ADD COLUMN IF NOT EXISTS unlock_trial_ids bigint[] NOT NULL DEFAULT '{}';

UPDATE shop_items SET unlock_trial_ids = COALESCE((
  SELECT array_agg(id) FROM sidequests
  WHERE name IN ('A Music player for the saloon', 'A Jukebox for the Saloon')
), '{}'::bigint[])
WHERE name = 'Music Grant';

UPDATE shop_items SET description =
  '$10 stackable grant for any music gear to become the next diva (no streaming subscriptions). LOCKED: unlock it by shipping the MP3 Player Trial or the Jukebox Trial in the Dustline.'
WHERE name = 'Music Grant';
