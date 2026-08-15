-- Shop images: point item image_url at the new compressed .webp files
-- (apps/landing/public/shop/*.webp — 17MB of PNG re-encoded to 1.9MB of WebP,
-- ~89% smaller, so the shop grid and item pages load much faster).
--
-- ⚠️  RUN THIS ONLY AFTER the landing has been redeployed with the .webp files.
--     The images are served from pixl.hackclub.com/shop/*, so until that deploy
--     the .webp URLs 404 (the shop would show placeholders). The .png files are
--     kept, so this is safe to run late and easy to revert (.webp$ -> .png).
--
-- Idempotent. Run in psql against the orchard/CNPG database.

UPDATE shop_items
SET image_url = regexp_replace(image_url, '\.png$', '.webp')
WHERE image_url ILIKE '%/shop/%.png';
