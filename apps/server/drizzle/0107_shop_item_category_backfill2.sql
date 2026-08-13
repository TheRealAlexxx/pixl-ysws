-- Items added to the catalog after 0106's name list was written.
UPDATE shop_items SET category = 'merch' WHERE name IN (
  'Community Meme Pack (5-Pack)', 'Pixl Sticker Pack', '3D Printed Blahaj'
);

UPDATE shop_items SET category = 'software' WHERE name = 'GTA VI (Standard Edition)';

UPDATE shop_items SET category = 'kits' WHERE name = 'Pixl Tamagotchi DIY Kit (Coming soon)';
