-- Super admins: the top tier, the only role that can hand out permissions and
-- promote other super admins. Until now that tier only existed as the
-- ADMIN_SLACK_IDS env allow-list, so adding an owner meant editing env vars and
-- redeploying. Listing someone here grants exactly what an env owner has.
-- Env owners stay valid (and can't be removed from the dashboard), so this
-- table can never lock everyone out.
create table if not exists super_admins (
  slack_id text primary key,
  name text not null default '',
  added_by text not null default '',
  created_at timestamptz not null default now()
);

insert into super_admins (slack_id, name, added_by)
values ('U0ARC79GEAV', 'Ridit', 'migration 0105')
on conflict (slack_id) do nothing;
