ALTER TABLE shop_items ADD COLUMN IF NOT EXISTS category text NOT NULL DEFAULT 'other';

UPDATE shop_items SET category = 'grants' WHERE name IN (
  'Hardware Grant', 'Domain Grant', 'CPU Grant', 'GPU Grant', 'RAM Grant',
  'Monitor Grant (Stackable)', 'Hosting Grant', 'Food Grant', 'Music Grant',
  'Art Supply Grant', 'Soldering Tools Grant', 'Game Assets Grant'
);

UPDATE shop_items SET category = 'merch' WHERE name IN (
  'Hack Club Sticker Pack', 'PIXL Hoodie', 'PIXL Poster', 'PIXL Cookie Cutter',
  'Signed Org Photo', 'Blahaj Plush', 'Godot Plush (Limited Edition)',
  'Random Desk Object'
);

UPDATE shop_items SET category = 'tech' WHERE name IN (
  'AirPods Max 2', 'AirPods Pro 3', 'Apple Pencil Pro', 'iPad (11th gen)',
  'iPad Air (M4, 128GB)', 'Mac Mini (24GB/512GB)', 'MacBook Air M5', 'MacBook Neo',
  'Nintendo Switch 2', 'Nothing Phone (4a) Pro', 'Samsung Galaxy S24',
  'Samsung T7 External SSD (1TB)', 'Sony WH-1000XM5', 'Sony WH-CH720N',
  'Retro Handheld (Miyoo Mini+ / RG35XX)', 'Wacom Intuos (Small)',
  'Epomaker x Aula S75 Pro', 'FURYCUBE 68%', 'Raspberry Pi 5', 'ESP32 Starter Kit',
  'Electric Screwdriver Set', 'Soldering Iron'
);

UPDATE shop_items SET category = 'printers' WHERE name IN (
  'Bambu Lab A1', 'Bambu Lab A1 Combo', 'Bambu Lab A1 Mini',
  'Creality Ender 3 V3', 'Creality Sparkx i7', 'Centauri Carbon'
);

UPDATE shop_items SET category = 'software' WHERE name IN (
  'Apple Developer License', 'Google Play Developer License', 'Aseprite License',
  'GameMaker Pro', 'PICO-8 License', 'Pixel Composer License', 'Steam License',
  'AI Credits', 'Indie Game of Your Choice'
);

UPDATE shop_items SET category = 'kits' WHERE name IN (
  'Framework 13 DIY', 'Framework 16 DIY', 'Pixl Tamagotchi DIY Kit'
);
