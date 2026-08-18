-- Journal entries could only be created/deleted, never edited. Add an
-- edited_at marker (nullable) so an edit route can stamp it and reviewers can
-- see an entry was changed after the fact, same transparency the rest of the
-- review trail already relies on.
ALTER TABLE "project_journals" ADD COLUMN IF NOT EXISTS "edited_at" timestamptz;
