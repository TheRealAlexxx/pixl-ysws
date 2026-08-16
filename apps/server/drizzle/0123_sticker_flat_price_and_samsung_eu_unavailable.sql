-- Two small shop fixes:
--
-- 1. Pixl Sticker Pack is a free trial reward / cheap merch item with no real
--    regional cost difference, so flatten it to 250px in every region (it was
--    350 everywhere except EUROPE, which was already 250).
--
-- 2. Samsung Galaxy S24 was DELETEd from EUROPE in 0114 ("not available
--    there"), which removed it from the EU catalog entirely. Put the row back
--    but at price 0 so the shop renders it as "NOT AVAILABLE — Coming soon to
--    this region" (the isPending state in apps/game/web/shop) and buy_shop_item
--    rejects it as not_for_sale, instead of the item silently vanishing.
--
-- Target: the orchard/CNPG database (the DB of record).
-- Idempotent. Safe to run more than once. Run in psql.

BEGIN;

UPDATE shop_items SET price = 250 WHERE name = 'Pixl Sticker Pack';

INSERT INTO shop_items
  (name, description, price, image_url, options, config_options,
   active, position, created_by, unlock_xp, category, region)
SELECT
  name, description, 0, image_url, options, config_options,
  true, position, created_by, unlock_xp, category, 'EUROPE'
FROM shop_items
WHERE name = 'Samsung Galaxy S24' AND region = 'US'
ON CONFLICT (name, region) DO NOTHING;

COMMIT;
