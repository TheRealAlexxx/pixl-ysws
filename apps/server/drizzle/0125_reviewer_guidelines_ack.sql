-- First-time reviewers must read the YSWS Project Submission Guidelines before
-- they can access the review queue. This table records that a reviewer (by
-- Slack id) acknowledged the guidelines, and at which content version — bump
-- GUIDELINES_VERSION in apps/dashboard/lib/guidelines.ts to force everyone to
-- re-read after a significant change.
--
-- Target: the orchard/CNPG database. Idempotent. Run in psql.

CREATE TABLE IF NOT EXISTS reviewer_guidelines_ack (
  slack_id text PRIMARY KEY,
  version integer NOT NULL DEFAULT 1,
  acked_at timestamptz NOT NULL DEFAULT now()
);
