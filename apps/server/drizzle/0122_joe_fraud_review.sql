-- Three-pass review: a first pass (any reviewer) now hands off to Joe
-- (joe.fraud.hackclub.com) for a fraud score, and only then to the final
-- human pass. status 'fraud_review' sits between 'shipped' and 'second_review'.
alter table projects add column if not exists joe_project_id text not null default '';
alter table projects add column if not exists joe_submitted_at timestamptz;
alter table projects add column if not exists joe_trust_score integer;
alter table projects add column if not exists joe_outcome text not null default '';
alter table projects add column if not exists joe_reason text not null default '';
alter table projects add column if not exists joe_reviewed_at timestamptz;
alter table projects add column if not exists joe_reviewer text not null default '';
alter table projects add column if not exists joe_error text not null default '';

create index if not exists projects_joe_project_id_idx on projects (joe_project_id)
  where joe_project_id <> '';
