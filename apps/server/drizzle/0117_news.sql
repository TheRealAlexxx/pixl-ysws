-- Program news, shown on the projects page and written from the dashboard.
-- Distinct from `notifications`, which are per-player inbox rows: these are one
-- public feed everybody reads.
create table if not exists news (
  id bigint generated always as identity primary key,
  body text not null,
  link_url text,
  posted_at timestamptz not null default now(),
  active boolean not null default true
);

create index if not exists news_posted_at_idx on news (posted_at desc);
