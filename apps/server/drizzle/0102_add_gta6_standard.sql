-- Add "GTA VI (Standard Edition)" to the shop, stocked in every region.
--
-- Prices come from the regional retail list (Gabin), converted to USD at the
-- exchange rates on 2026-08-10, then to pixels with the shop's standard
-- formula: hours = price_usd / 3.5, rounded to the nearest half hour,
-- pixels = hours * 50. For regions that list several countries, the USD
-- values are averaged across those countries before the formula is applied.
--
--   Region          local price(s)                 -> USD (avg)   -> h    -> px
--   US              $79.99                             79.99        23.0    1150
--   NORTH_AMERICA   CAD 109.99 / MXN 1499              83.14        24.0    1200
--   SOUTH_AMERICA   R$449.90                           88.42        25.5    1275
--   EUROPE          79.99 EUR / 69.99 GBP              93.40        26.5    1325
--   ASIA            KRW 89800 / JPY 9800 / HKD 568     66.06        19.0     950
--   INDIA           INR 5999                           62.98        18.0     900
--   AFRICA          ZAR 1499                           92.73        26.5    1325
--
-- Image needs to be created/uploaded to pixl.rsvp/shop/gta-vi.png before this
-- goes live in-game.
--
-- Safe to run once. Re-running is a no-op (row already exists per region).
-- Run this in the Supabase SQL editor.

INSERT INTO shop_items (name, description, price, image_url, options, active, position, created_by, unlock_xp, region)
SELECT
  'GTA VI (Standard Edition)',
  'Rockstar''s Grand Theft Auto VI, standard edition. The most anticipated open-world game there is — yours to play.',
  v.price,
  'https://pixl.rsvp/shop/gta-vi.png',
  '[]'::jsonb,
  true,
  (SELECT coalesce(max(position), 0) + 1 FROM shop_items x WHERE x.region = v.region),
  'landing-sync',
  0,
  v.region
FROM (VALUES
  ('US', 1150),
  ('NORTH_AMERICA', 1200),
  ('SOUTH_AMERICA', 1275),
  ('EUROPE', 1325),
  ('ASIA', 950),
  ('INDIA', 900),
  ('AFRICA', 1325)
) AS v(region, price)
WHERE NOT EXISTS (
  SELECT 1 FROM shop_items e
  WHERE e.name = 'GTA VI (Standard Edition)' AND e.region = v.region
);
