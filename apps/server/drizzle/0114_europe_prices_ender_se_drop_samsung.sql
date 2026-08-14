-- Shop: fill in the EUROPE prices that were left as TBD (0) when the region was
-- first stocked (0097), switch the Creality Ender to the V3 SE model in every
-- region, and pull the Samsung Galaxy S24 from the EU shop (not available there).
--
-- EU pixel prices follow the same pipeline as 0097/0104: EU retail EUR (incl.
-- VAT) → USD @ 1.1546 → hours rounded to 0.5h → ×50 → +10% rounded to 25px.
-- US/India Ender SE stay at 3125 (~$199, the same as the old V3 row).
--
-- Already applied to the orchard/CNPG database. Idempotent. Run in psql.

BEGIN;

-- Ender 3 V3 -> the V3 SE model, all regions. Renamed first so the EU price
-- update below can key on the new name.
UPDATE shop_items SET name = 'Creality Ender 3 V3 SE' WHERE name = 'Creality Ender 3 V3';

-- EUROPE prices (EUR in the trailing comment)
UPDATE shop_items SET price = 1100  WHERE name = 'Wacom Intuos (Small)'   AND region = 'EUROPE'; -- 60
UPDATE shop_items SET price = 3075  WHERE name = 'Creality Ender 3 V3 SE' AND region = 'EUROPE'; -- 170
UPDATE shop_items SET price = 4550  WHERE name = 'Sony WH-1000XM5'        AND region = 'EUROPE'; -- 250
UPDATE shop_items SET price = 4700  WHERE name = 'Creality Sparkx i7'     AND region = 'EUROPE'; -- 259
UPDATE shop_items SET price = 5650  WHERE name = 'Centauri Carbon'        AND region = 'EUROPE'; -- 310
UPDATE shop_items SET price = 10525 WHERE name = 'AirPods Max 2'          AND region = 'EUROPE'; -- 580
UPDATE shop_items SET price = 200   WHERE name = 'Soldering Iron'         AND region = 'EUROPE'; -- 10

-- Samsung Galaxy S24 not available in EU -> removed from the EU shop entirely.
DELETE FROM shop_items WHERE name = 'Samsung Galaxy S24' AND region = 'EUROPE';

COMMIT;
