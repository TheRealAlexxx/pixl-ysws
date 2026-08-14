-- description/repo_url/demo_url existed on the old Supabase projects table but
-- were never written into a migration file, so the Orchard database was built
-- without them. The create-project route has inserted all three since ad0fd8f,
-- which meant every create failed with 42703 "column description does not exist".
--
-- Applied directly to prod on 2026-08-15 to unblock creation; kept here so the
-- schema is reproducible. IF NOT EXISTS makes re-running a no-op.
-- Types match the other free-text columns on this table (ai_notes, review_note,
-- image_url): text NOT NULL DEFAULT '' so reads never have to handle null.
ALTER TABLE projects ADD COLUMN IF NOT EXISTS description text NOT NULL DEFAULT '';
ALTER TABLE projects ADD COLUMN IF NOT EXISTS repo_url    text NOT NULL DEFAULT '';
ALTER TABLE projects ADD COLUMN IF NOT EXISTS demo_url    text NOT NULL DEFAULT '';
