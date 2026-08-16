-- The Pixl Sticker Pack was only stocked in 5 of the 7 regions (AFRICA, ASIA,
-- EUROPE, NORTH_AMERICA, SOUTH_AMERICA) — it was missing from US and INDIA.
-- Every other merch item (Godot Plush, Cookie Cutter, Poster, Hoodie, Meme
-- Pack, Signed Org Photo, Random Desk Object) is stocked uniformly across all
-- regions at the same price, so the sticker pack's two gaps are just an
-- oversight, not an intentional region restriction.
--
-- Backfill US and INDIA by cloning the NORTH_AMERICA row (price 350, the price
-- shared by every region except EUROPE, which sits at 250 — an existing
-- discrepancy left untouched here). The (name, region) unique constraint from
-- 0100 means ON CONFLICT DO NOTHING makes this idempotent.
--
-- Safe to run more than once. Run this in the Supabase SQL editor.

INSERT INTO shop_items
  (name, description, price, image_url, options, config_options,
   active, position, created_by, unlock_xp, category, region)
SELECT
  src.name, src.description, src.price, src.image_url, src.options,
  src.config_options, src.active, src.position, src.created_by,
  src.unlock_xp, src.category, r.region
FROM shop_items src
CROSS JOIN (VALUES ('US'), ('INDIA')) AS r(region)
WHERE src.name = 'Pixl Sticker Pack'
  AND src.region = 'NORTH_AMERICA'
ON CONFLICT (name, region) DO NOTHING;
