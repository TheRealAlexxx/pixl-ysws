-- New shop item: Huawei MatePad 11.5 (PaperMatte), regionally priced with a
-- unified "Version" configurator (base = 128GB standard, add-ons for M-Pencil
-- and the 256GB PaperMatte upgrade). Prices via the standard pipeline
-- (local retail -> USD -> hours round 0.5 -> x50 -> x1.1 round 25):
--   AFRICA  : South Africa ZAR @16.5 (real Huawei ZA promo prices)
--   EUROPE  : EUR @1.1546 (averaged across UK/DE/AT/FR; the 128GB/pencil
--             sub-versions are synthesized from the ZA ratios since the EU
--             "S 2026" model only really sells the 256GB flagship)
--   INDIA   : INR @83.5 (Flipkart Rs43,999) — only the 256GB, keyboard,
--             NO M-Pencil version is sold there, so it's a flat price, no
--             configurator.
-- Not officially sold in the US / Canada / South America / (SG) Asia -> those
-- regions get a price-0 row so the shop shows "NOT AVAILABLE" there.
--
-- Image served from the landing CDN (apps/landing/public/shop/matepad-11.webp).
-- Target: the orchard/CNPG database. Idempotent (ON CONFLICT on name+region).

-- AFRICA (real ZA prices): base R5,699 -> 5425 px; +pencil +300; +256GB PaperMatte +2200
INSERT INTO shop_items (name, description, price, image_url, options, config_options, active, position, created_by, unlock_xp, category, region)
VALUES (
  'Huawei MatePad 11.5',
  'Huawei MatePad 11.5 PaperMatte tablet with a detachable keyboard (and M-Pencil lite on the higher versions). 2.5K 120Hz display, 8GB RAM. Pick your version below.',
  5975, 'https://pixl.hackclub.com/shop/matepad-11.webp', '[]'::jsonb,
  '{"base_price":5425,"reference_url":"https://consumer.huawei.com/za/offer/huawei-tablets/matepad-11-5-2025-buy/","groups":[{"name":"Version","type":"single","choices":[{"label":"8GB + 128GB Standard, with Keyboard (no M-Pencil)","price":0},{"label":"8GB + 128GB Standard, with M-Pencil lite & Keyboard","price":300},{"label":"8GB + 256GB PaperMatte, with M-Pencil lite & Keyboard","price":2200}]}]}'::jsonb,
  true, 62, 'landing-sync', 0, 'tech', 'AFRICA'
) ON CONFLICT (name, region) DO NOTHING;

-- EUROPE (averaged EUR; V1/V2 synthesized): base 6100 px; +pencil +300; +256GB PaperMatte +2450
INSERT INTO shop_items (name, description, price, image_url, options, config_options, active, position, created_by, unlock_xp, category, region)
VALUES (
  'Huawei MatePad 11.5',
  'Huawei MatePad 11.5 PaperMatte tablet with a detachable keyboard (and M-Pencil lite on the higher versions). 2.5K 120Hz display, 8GB RAM. Pick your version below.',
  6700, 'https://pixl.hackclub.com/shop/matepad-11.webp', '[]'::jsonb,
  '{"base_price":6100,"reference_url":"https://consumer.huawei.com/uk/tablets/matepad-11-5-s-2026/buy/","groups":[{"name":"Version","type":"single","choices":[{"label":"8GB + 128GB Standard, with Keyboard (no M-Pencil)","price":0},{"label":"8GB + 128GB Standard, with M-Pencil lite & Keyboard","price":300},{"label":"8GB + 256GB PaperMatte, with M-Pencil lite & Keyboard","price":2450}]}]}'::jsonb,
  true, 62, 'landing-sync', 0, 'tech', 'EUROPE'
) ON CONFLICT (name, region) DO NOTHING;

-- INDIA (Rs43,999, 256GB + keyboard, NO M-Pencil): flat price, no configurator
INSERT INTO shop_items (name, description, price, image_url, options, config_options, active, position, created_by, unlock_xp, category, region)
VALUES (
  'Huawei MatePad 11.5',
  'Huawei MatePad 11.5 PaperMatte tablet, 8GB + 256GB, with a detachable keyboard. 2.5K 120Hz display. (The M-Pencil version is not sold in India.)',
  8275, 'https://pixl.hackclub.com/shop/matepad-11.webp', '[]'::jsonb, NULL,
  true, 62, 'landing-sync', 0, 'tech', 'INDIA'
) ON CONFLICT (name, region) DO NOTHING;

-- Not sold in these regions -> price 0 shows "NOT AVAILABLE".
INSERT INTO shop_items (name, description, price, image_url, options, config_options, active, position, created_by, unlock_xp, category, region)
SELECT 'Huawei MatePad 11.5',
  'Huawei MatePad 11.5 PaperMatte tablet with detachable keyboard.',
  0, 'https://pixl.hackclub.com/shop/matepad-11.webp', '[]'::jsonb, NULL,
  true, 62, 'landing-sync', 0, 'tech', r.region
FROM (VALUES ('US'), ('NORTH_AMERICA'), ('SOUTH_AMERICA'), ('ASIA')) AS r(region)
ON CONFLICT (name, region) DO NOTHING;
