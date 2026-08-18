-- Projects are now split into two review tracks: software and hardware. `kind`
-- is picked by the builder at creation. It drives two things:
--   1. Ship gating: a hardware project does NOT require Hackatime — its tracked
--      time is journal hours + Hackatime hours combined, so journals alone are
--      enough. Software keeps the Hackatime floor.
--   2. Review routing: hardware ships go to their own review queue
--      (/review/hardware) instead of the software one (/review).
--
-- Backfill: existing projects whose granular project_type is hardware/cad start
-- as 'hardware'; everything else is 'software'.
--
-- Target: the orchard/CNPG database. Idempotent. Run in psql.

ALTER TABLE projects
  ADD COLUMN IF NOT EXISTS kind text NOT NULL DEFAULT 'software';

UPDATE projects SET kind = 'hardware'
  WHERE kind = 'software' AND project_type IN ('hardware', 'cad');
