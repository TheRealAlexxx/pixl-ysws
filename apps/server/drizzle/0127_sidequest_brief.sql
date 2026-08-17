-- Sidequests get a `brief`: a longer, spec-style description with precise
-- deliverables and acceptance criteria, shown in the in-game Builder Terminal
-- AFTER the player has accepted the Trial (the short `description` is what the
-- NPC shows up front). Editable from the dashboard /sidequests page.
--
-- Target: the orchard/CNPG database. Idempotent. Run in psql.

alter table sidequests add column if not exists brief text not null default '';

-- Seed briefs for the Trials that exist today (keyed by name). Re-running just
-- resets them to these values, which is fine.
update sidequests set brief =
  'Ship a personal Builder page that introduces you. Deliver: (1) your name/handle and one line on what you build; (2) at least one thing you have made (a link or a screenshot counts); (3) a way to reach you (GitHub, email, or a social). Plain HTML/CSS is enough, no framework required. Deploy it somewhere public (GitHub Pages, Vercel, Neocities...) and use that live URL as your Playable URL, with the code on GitHub (README included). Make it yours: your colors, your vibe. ~4h.'
  where name = 'Raise your Builder Page';

update sidequests set brief =
  'This one is open, stake your claim however you want. Build and ship anything that is genuinely yours: a game, a tool, a site, a gadget. It has to actually work (an MVP is fine), live on GitHub with a README, and be experienceable by anyone in under 2 minutes. No theme, no scope limit, just make something you are proud to plant a flag on.'
  where name = 'Claim Your Stake';

update sidequests set brief =
  'Deliver TWO physical devices that relay a message over radio only (no wifi, no internet, no phone/bluetooth link). Pick one mode: voice (mic + speaker) or text/morse (buttons + display or LEDs). Requirements: (1) both units are self-powered (battery); (2) a message sent on one is received on the other, and you state the range you actually hit; (3) the repo has wiring diagrams/schematics, any CAD in a modifiable format (.STEP/.blend, not .STL), and a README with the parts list and build steps; (4) include a demo video of a message crossing. LoRa, nRF24, or 433MHz modules are all fair game. Minimum 40h tracked.'
  where name = 'Contact the hackclubbers on earth for more support!';

update sidequests set brief =
  'Design a region, then make it playable. Deliver: (1) a region map, (2) a tileset, (3) at least 2 NPCs with written dialogue, (4) 1 sidequest hook, and (5) a coded, walkable demo of it. Rule: art time is at most half your logged hours (max 11h art on a 22h Trial), and you log art and code separately so the split is visible. Ship a playable build (web/itch/download) plus the code on GitHub with a README. Minimum 22h tracked.'
  where name = 'Draw It Before It''s Real';

update sidequests set brief =
  'Build a physical music player. Requirements: (1) load YOUR OWN audio files onto it (SD card or flash); (2) play them through real speakers, no phone, no app, no streaming; (3) physical buttons for play, pause, skip, and volume; (4) a battery that lasts a full night, and you state the runtime you got. Repo: a wiring diagram/schematic, the enclosure CAD in a modifiable format (.STEP/.blend), and a README with the parts list and build steps. Add a demo video. An ESP32, Pi Pico, or Arduino plus a DAC/amp is a good starting point. Minimum 15h tracked.'
  where name = 'A Music player for the saloon';

update sidequests set brief =
  'Deliver a published, playable Roblox experience. Requirements: (1) it is your own build in Studio, any genre or theme; (2) there is a real goal or loop, not an empty baseplate, a way to win, score, explore, or complete something; (3) it is published public so anyone can play from the link (that link is your Playable URL); (4) the place file/scripts are on GitHub with a README. Build the thing you would actually want to click into. Minimum 5h tracked.'
  where name = 'Make me a Roblox game!';
