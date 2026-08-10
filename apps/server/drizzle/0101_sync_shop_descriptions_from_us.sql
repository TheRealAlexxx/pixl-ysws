-- Descriptions were edited on the US catalog. Every other region keeps its own
-- shop_items rows (one per region, matched by name), so those edits don't reach
-- ASIA / NORTH_AMERICA / SOUTH_AMERICA / EUROPE / INDIA / AFRICA on their own.
-- This copies each US item's description onto the same-named item in every other
-- region so the whole catalog reads the same everywhere.
--
-- Safe to run once. Re-running is a no-op (regions already match the US text).
-- Note: this overwrites any region-specific description text with the US copy.
-- Run this in the Supabase SQL editor.

UPDATE shop_items AS t
SET description = us.description
FROM shop_items AS us
WHERE us.region = 'US'
  AND t.name = us.name
  AND t.region <> 'US'
  AND t.description IS DISTINCT FROM us.description;
