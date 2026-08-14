-- Track people joining the main Pixl Slack channel, so pixorpheus can post a
-- single end-of-day digest welcoming all of the day's new members instead of an
-- instant per-join welcome message.
--
-- user_id is the primary key so a leave+rejoin doesn't create a duplicate (and
-- doesn't re-announce someone already welcomed). `announced` flips to true once
-- a member has been included in a digest. The partial index keeps the "who
-- hasn't been announced yet" lookup cheap.
--
-- Run this against the orchard/CNPG database. Safe to run more than once.

CREATE TABLE IF NOT EXISTS public.member_joins (
  user_id   text        PRIMARY KEY,
  channel   text        NOT NULL,
  joined_at timestamptz NOT NULL DEFAULT now(),
  announced boolean     NOT NULL DEFAULT false
);

CREATE INDEX IF NOT EXISTS member_joins_unannounced_idx
  ON public.member_joins (channel)
  WHERE announced = false;
