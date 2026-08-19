-- The Pixl Sticker Pack is custom-designed per batch, not off-the-shelf stock,
-- so it can take longer to fulfil than other merch while a new design gets
-- made. Buyers weren't told this up front.
--
-- Append rather than overwrite: the description has been hand-edited more than
-- once outside of migrations (see 0056), so we don't know its exact current
-- text, only that it doesn't yet mention fulfillment time. Idempotent via the
-- NOT LIKE guard.
--
-- Run this in the Supabase SQL editor. Safe to run more than once.

UPDATE shop_items
SET description = description || ' Note: these are custom-designed, so orders can take a bit longer to fulfil while we design and print a new batch.'
WHERE name = 'Pixl Sticker Pack'
  AND created_by = 'landing-sync'
  AND description NOT LIKE '%can take a bit longer to fulfil%';
