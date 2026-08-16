-- Framework 13/16 DIY were US + NORTH_AMERICA only (both at US prices — see the
-- note in 0097/0115 excluding them from the regional backfill because their
-- config_options are US-specced). Stock them in the remaining regions, but
-- honestly: Framework only officially sells in the US, Canada (NORTH_AMERICA)
-- and the EU. It does NOT ship to Singapore (the ASIA proxy market), India,
-- Africa or most of South America.
--
--   * EUROPE  -> real pricing. base_price localized via the 0114 EU pipeline:
--       EU retail EUR (incl VAT) -> USD @ 1.1546 -> hours round 0.5 -> x50
--       -> x1.1 round 25. FW13 DIY base EUR1349 (Intel Ultra 5, barebones,
--       heise.de) -> 24475 px. FW16 DIY EU base isn't cleanly quoted, so it's
--       estimated from FW13's US->EU ratio (17129->24475 = x1.429) applied to
--       FW16's US base 17843 -> 25500 px (~est). The top-level display `price`
--       column keeps the repo's base_price x1.1 (round 25) convention:
--       FW13 26925, FW16 28050. Every config_options CHOICE price is left in
--       the existing USD-pixel values (commodity RAM/SSD/etc add-ons; the
--       pixel is a global time-currency, and re-pricing ~50 options per region
--       is exactly the breakage risk the exclusion note warned about).
--
--   * ASIA / INDIA / AFRICA / SOUTH_AMERICA -> not sold there. Row inserted at
--       top-level price 0 so the shop renders it "NOT AVAILABLE — Coming soon
--       to this region" (isPending in apps/game/web/shop/index.html + the
--       config-item guard added to apps/game/web/shop/item/index.html) and
--       buy_shop_item rejects it as not_for_sale. config_options is cloned
--       from US so the item is ready to flip on if Framework ever expands.
--
-- NOTE: the "NOT AVAILABLE" rendering for a *configurable* item needs the two
-- apps/game/web/shop frontend edits in this commit deployed. Until then those
-- four regions show a buildable-but-unbuyable Framework (server still rejects
-- the purchase), it just isn't labelled unavailable yet.
--
-- Target: the orchard/CNPG database. Idempotent (ON CONFLICT DO NOTHING on the
-- (name, region) unique constraint). Safe to run more than once. Run in psql.

BEGIN;

-- EUROPE: localized base_price + display price, options untouched.
INSERT INTO shop_items
  (name, description, price, image_url, options, config_options,
   active, position, created_by, unlock_xp, category, region)
SELECT name, description, 26925, image_url, options,
  jsonb_set(config_options, '{base_price}', to_jsonb(24475)),
  active, position, created_by, unlock_xp, category, 'EUROPE'
FROM shop_items WHERE name = 'Framework 13 DIY' AND region = 'US'
ON CONFLICT (name, region) DO NOTHING;

INSERT INTO shop_items
  (name, description, price, image_url, options, config_options,
   active, position, created_by, unlock_xp, category, region)
SELECT name, description, 28050, image_url, options,
  jsonb_set(config_options, '{base_price}', to_jsonb(25500)),
  active, position, created_by, unlock_xp, category, 'EUROPE'
FROM shop_items WHERE name = 'Framework 16 DIY' AND region = 'US'
ON CONFLICT (name, region) DO NOTHING;

-- ASIA / INDIA / AFRICA / SOUTH_AMERICA: present but NOT AVAILABLE (price 0).
INSERT INTO shop_items
  (name, description, price, image_url, options, config_options,
   active, position, created_by, unlock_xp, category, region)
SELECT s.name, s.description, 0, s.image_url, s.options, s.config_options,
  true, s.position, s.created_by, s.unlock_xp, s.category, r.region
FROM shop_items s
CROSS JOIN (VALUES ('ASIA'), ('INDIA'), ('AFRICA'), ('SOUTH_AMERICA')) AS r(region)
WHERE s.name IN ('Framework 13 DIY', 'Framework 16 DIY') AND s.region = 'US'
ON CONFLICT (name, region) DO NOTHING;

COMMIT;
