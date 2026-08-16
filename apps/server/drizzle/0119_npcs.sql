-- Authorable NPCs. Until now every NPC was a hand-placed node in village.tscn /
-- open_world.tscn, so adding one meant opening the Godot editor and shipping a
-- new client build. This table mirrors the @export set on scripts/npc.gd one
-- column per export, so the dashboard can author an NPC (spot on the map, skin,
-- dialogue, which Trial it gives) and the client spawns it at runtime.
--
-- `npc_name` is the identity: npc.gd's npc_id() returns npc_name, and the
-- server's saved-NPC-position sync (ws/gameServer) keys off that id. Hence the
-- unique (world, npc_name) - two NPCs sharing a name in one world would fight
-- over the same saved position.
--
-- route_path is deliberately absent: it points at a Path2D node inside a scene,
-- which has no meaning outside the editor and can't be authored from a form.
create table if not exists npcs (
  id bigint generated always as identity primary key,
  world text not null default 'village',
  pos_x real not null default 0,
  pos_y real not null default 0,
  npc_name text not null,
  skin text not null default 'cvc:1',
  custom_hair text not null default '',
  custom_sheet text not null default '',
  dialogue text not null default '',

  -- Interaction modes, matching npc.gd's exports. All independent booleans
  -- rather than one enum because npc.gd treats them as independent.
  opens_projects boolean not null default false,
  opens_explore boolean not null default false,
  quest_project boolean not null default false,
  faq boolean not null default false,
  quest_trial boolean not null default false,
  trial_checkin boolean not null default false,

  -- The Trial this NPC hands out. npc.gd matches Trials by name; storing the id
  -- instead means renaming a Trial in the dashboard can't silently orphan its
  -- giver, and the API resolves the current name on read.
  sidequest_id bigint references sidequests(id) on delete set null,
  quest_offer text not null default '',
  quest_done text not null default '',
  trial_reminder text not null default '',

  wanders boolean not null default true,
  speed real not null default 50,
  wander_radius real not null default 56,
  min_wait real not null default 1.2,
  max_wait real not null default 4.5,

  active boolean not null default true,
  sort_order integer not null default 0,
  created_by text not null default '',
  created_at timestamptz not null default now(),

  unique (world, npc_name)
);
--> statement-breakpoint
create index if not exists npcs_world_active_idx on npcs (world, active);
