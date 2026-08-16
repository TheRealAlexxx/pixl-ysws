-- Migrate the seven hand-placed NPCs out of village.tscn / open_world.tscn and
-- into the npcs table, so the client can spawn them from data and the dashboard
-- can edit them. Copy is preserved byte-for-byte from the scene files (extracted
-- programmatically, not retyped).
--
-- Trial-givers resolve their sidequest_id by Trial name at insert time; if a
-- Trial row is missing the NPC still seeds with a null link rather than failing,
-- and the dashboard can re-link it.
--
-- Idempotent: on conflict (world, npc_name) do nothing. Note "Ridit" appears in
-- both worlds (the open-world giver and the village check-in copy) - that's two
-- distinct rows, which the (world, npc_name) key allows.
-- 7 NPCs extracted from the world scenes
insert into npcs (
  world, npc_name, pos_x, pos_y, skin, custom_hair, custom_sheet, dialogue,
  opens_projects, opens_explore, quest_project, faq, quest_trial, trial_checkin,
  sidequest_id, quest_offer, quest_done, trial_reminder,
  wanders, speed, wander_radius, min_wait, max_wait, sort_order, created_by
) values (
  'village', 'Pip', 120.0, -81.0, 'cvc:4',
  '', '', 'Built something? Talk to me to log your project.',
  true, false,
  false, false,
  false, false,
  null, '', '', '',
  true, 50.0, 56.0, 1.2, 4.5,
  0, 'scene-migration'
) on conflict (world, npc_name) do nothing;
insert into npcs (
  world, npc_name, pos_x, pos_y, skin, custom_hair, custom_sheet, dialogue,
  opens_projects, opens_explore, quest_project, faq, quest_trial, trial_checkin,
  sidequest_id, quest_offer, quest_done, trial_reminder,
  wanders, speed, wander_radius, min_wait, max_wait, sort_order, created_by
) values (
  'village', 'Pixo', 170.0, -20.0, 'cvc:1',
  '', '', 'Hey! I''m Pixo. Got questions about how any of this works? Ask away.',
  false, false,
  false, true,
  false, false,
  null, '', '', '',
  false, 50.0, 56.0, 1.2, 4.5,
  1, 'scene-migration'
) on conflict (world, npc_name) do nothing;
insert into npcs (
  world, npc_name, pos_x, pos_y, skin, custom_hair, custom_sheet, dialogue,
  opens_projects, opens_explore, quest_project, faq, quest_trial, trial_checkin,
  sidequest_id, quest_offer, quest_done, trial_reminder,
  wanders, speed, wander_radius, min_wait, max_wait, sort_order, created_by
) values (
  'village', 'Ridit', 180.0, -140.0, 'cvc:3',
  '', '', 'Howdy again, partner.',
  false, false,
  false, false,
  true, true,
  (select id from sidequests where name = 'The Wall at the Sixteen Colors' order by id limit 1), '', 'Mabel''s wall is back up, partner. Proud of you.
The frontier''s wide open now — plenty more Trials where that came from.', 'Come to check on your work, partner. How''s The Wall at the Sixteen Colors comin''?
Get the noticeboard site posting and filterin'', log your hours, ship it when it''s real. I''ll open the ledger.',
  false, 50.0, 56.0, 1.2, 4.5,
  2, 'scene-migration'
) on conflict (world, npc_name) do nothing;
insert into npcs (
  world, npc_name, pos_x, pos_y, skin, custom_hair, custom_sheet, dialogue,
  opens_projects, opens_explore, quest_project, faq, quest_trial, trial_checkin,
  sidequest_id, quest_offer, quest_done, trial_reminder,
  wanders, speed, wander_radius, min_wait, max_wait, sort_order, created_by
) values (
  'open_world', 'Ridit', -804.0, 460.0, 'cvc:3',
  '', '', 'Howdy, partner. Welcome to the Dustline.',
  false, false,
  false, false,
  true, false,
  (select id from sidequests where name = 'The Wall at the Sixteen Colors' order by id limit 1), 'Made it out to the frontier, huh? Good. The Dustline''s held on two hundred years without the Core''s help, and it''ll keep holding — but the noticeboard at the Sixteen Colors fell apart, and Mabel could use a hand rebuilding it as a proper site. Posts, browse, filter by type. That''s the job.', 'Good job, partner. The frontier''s proud of you.', 'Still on the noticeboard? Get it posting and filterin'', log your hours, ship it when it''s real. I''ll open the ledger.',
  false, 50.0, 56.0, 1.2, 4.5,
  3, 'scene-migration'
) on conflict (world, npc_name) do nothing;
insert into npcs (
  world, npc_name, pos_x, pos_y, skin, custom_hair, custom_sheet, dialogue,
  opens_projects, opens_explore, quest_project, faq, quest_trial, trial_checkin,
  sidequest_id, quest_offer, quest_done, trial_reminder,
  wanders, speed, wander_radius, min_wait, max_wait, sort_order, created_by
) values (
  'open_world', 'Wren', -1078.0, 571.0, 'cvc:5',
  '', '', 'Everything starts as a drawing before the Core can make it real.',
  false, false,
  false, false,
  true, false,
  (select id from sidequests where name = 'Draw It Before It''s Real' order by id limit 1), 'I draft what doesn''t exist yet — maps, tilesets, whole regions — so the Core has a plan to rebuild from. Draft one yourself: a map, a tileset, at least two NPCs with dialogue, one sidequest hook. Then code a playable demo of it. Keep the art under half your logged hours — split the time log.', 'Good job, that draft came together exactly right.', 'How''s the draft coming? Map, tileset, two NPCs, a hook — then make it playable. Half your hours on art, tops.',
  false, 50.0, 56.0, 1.2, 4.5,
  4, 'scene-migration'
) on conflict (world, npc_name) do nothing;
insert into npcs (
  world, npc_name, pos_x, pos_y, skin, custom_hair, custom_sheet, dialogue,
  opens_projects, opens_explore, quest_project, faq, quest_trial, trial_checkin,
  sidequest_id, quest_offer, quest_done, trial_reminder,
  wanders, speed, wander_radius, min_wait, max_wait, sort_order, created_by
) values (
  'open_world', 'Rill', -1134.0, 703.0, 'cvc:7',
  '', '', 'Carry enough water out here and you start wondering how deep the well really is.',
  false, false,
  false, false,
  true, false,
  (select id from sidequests where name = 'How Deep Is It' order by id limit 1), 'Nobody out here knows how deep the well runs ''til it runs dry. Build me a gauge: a sensor down the shaft, a readout up top, a warning when it''s getting low. Has to run on battery for weeks, survive the dust, and work with no laptop tether.', 'Good job. The well''s finally got eyes on it.', 'Gauge still coming along? Sensor down the shaft, readout up top, low-level warning — and it''s gotta run for weeks on its own.',
  false, 50.0, 56.0, 1.2, 4.5,
  5, 'scene-migration'
) on conflict (world, npc_name) do nothing;
insert into npcs (
  world, npc_name, pos_x, pos_y, skin, custom_hair, custom_sheet, dialogue,
  opens_projects, opens_explore, quest_project, faq, quest_trial, trial_checkin,
  sidequest_id, quest_offer, quest_done, trial_reminder,
  wanders, speed, wander_radius, min_wait, max_wait, sort_order, created_by
) values (
  'open_world', 'Cass', -763.0, 684.0, 'cvc:8',
  '', '', 'Two hundred years and the relay''s never gone quiet. I aim to keep it that way.',
  false, false,
  false, false,
  true, false,
  (select id from sidequests where name = 'Two Hundred Years of Sending' order by id limit 1), 'The relay''s carried word across the Dustline for two centuries — no wifi, no Core, just radio. Build me a repeater: two physical devices that pass a message across on radio alone, with a screen that clicks on arrival. If you''d rather build the software side, implement the protocol plus a playable packet-crossing simulator instead.', 'Good job. The relay''s in good hands now.', 'Repeater still in pieces? Two devices, radio only, a screen that clicks when the message lands.',
  false, 50.0, 56.0, 1.2, 4.5,
  6, 'scene-migration'
) on conflict (world, npc_name) do nothing;
