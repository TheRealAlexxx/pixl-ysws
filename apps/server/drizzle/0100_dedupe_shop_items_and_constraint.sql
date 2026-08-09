-- Two "Nintendo Switch 2" rows existed in the US region (confirmed via the
-- dashboard Shop admin page) even though every migration ever written only
-- INSERTs it once (0062). There's no unique constraint on (name, region), so
-- a duplicate could slip in from the dashboard's manual "Add Item" form (its
-- duplicate check only catches an identical name created in the last 60
-- seconds) or a re-run bulk upload.
--
-- 1. Deduplicate the whole table generically (not just Switch 2) — for every
--    (name, region) pair with more than one active row, keep the
--    lowest-id (oldest) row and delete the rest.
-- 2. Add a real unique constraint so this can't happen again.
--
-- Run this in the Supabase SQL editor. Safe to run more than once.

DELETE FROM shop_items a
WHERE EXISTS (
  SELECT 1 FROM shop_items b
  WHERE b.name = a.name AND b.region = a.region AND b.id < a.id
);

ALTER TABLE shop_items DROP CONSTRAINT IF EXISTS shop_items_name_region_unique;
ALTER TABLE shop_items ADD CONSTRAINT shop_items_name_region_unique UNIQUE (name, region);
