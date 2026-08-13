-- pixl.rsvp's Vercel deployment was torn down in the Orchard migration; the
-- domain now 404s (DEPLOYMENT_NOT_FOUND). Shop item images are static files
-- served by apps/landing and still exist there, just under the new canonical
-- domain (packages/config/pixl.json's "site" url) — only the DB rows were
-- left pointing at the dead one.
UPDATE shop_items
SET image_url = replace(image_url, 'https://pixl.rsvp', 'https://pixl.hackclub.com')
WHERE image_url LIKE 'https://pixl.rsvp/%';
