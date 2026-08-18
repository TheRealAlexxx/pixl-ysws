-- Merge "Bambu Lab A1" and "Bambu Lab A1 Combo" into one configurable item. The
-- A1 gets a "Version" selector: the standard A1 (base price, +0) or the Combo
-- (+ AMS Lite, priced at the per-region delta the two separate rows had). Each
-- choice carries its own image so the detail page swaps the picture on select.
-- The old standalone Combo rows are deactivated (the option lives on the A1 now).
--
-- Per-region base + delta (px), from the old A1 / A1 Combo prices:
--   AFRICA 8750 +450 | ASIA 5400 +1475 | EUROPE 6125 +2650 | INDIA 6275 +300
--   NORTH_AMERICA 6275 +300 | SOUTH_AMERICA 10600 +4200 | US 6275 +300
--
-- Target: the orchard/CNPG database. Idempotent. Run in psql.

BEGIN;

UPDATE shop_items SET description =
  'A reliable, well-rounded 3D printer for props, cases and prototypes. Pick the standard A1, or upgrade to the Combo (adds the AMS Lite for multi-color printing).'
WHERE name = 'Bambu Lab A1';

-- Per-region config. base_price mirrors the row price; the Combo choice adds the delta.
UPDATE shop_items SET config_options =
  ('{"base_price":' || price || ',"groups":[{"name":"Version","type":"single","choices":['
   || '{"label":"A1 (single-color)","price":0,"image":"https://pixl.hackclub.com/shop/bambu-a1.webp"},'
   || '{"label":"A1 Combo (+ AMS Lite, multi-color)","price":' || d.delta || ',"image":"https://pixl.hackclub.com/shop/bambu-a1-combo.webp"}'
   || ']}]}')::jsonb
FROM (VALUES
  ('AFRICA', 450), ('ASIA', 1475), ('EUROPE', 2650), ('INDIA', 300),
  ('NORTH_AMERICA', 300), ('SOUTH_AMERICA', 4200), ('US', 300)
) AS d(region, delta)
WHERE shop_items.name = 'Bambu Lab A1' AND shop_items.region = d.region;

-- The Combo is now a choice on the A1, so retire the standalone rows.
UPDATE shop_items SET active = false WHERE name = 'Bambu Lab A1 Combo';

COMMIT;
