-- Reviewers can mark an already-approved project as "Peak": a purely
-- cosmetic badge shown on the project everywhere it's displayed publicly,
-- with no payout/pixel effect. See apps/dashboard/app/actions.ts toggleProjectPeak.
ALTER TABLE "projects" ADD COLUMN IF NOT EXISTS "is_peak" boolean NOT NULL DEFAULT false;
