-- The `notifications` table was never created. Every insert/select against it
-- (routes/notifications.ts, moderation.ts, reports.ts, dashboard/app/actions.ts)
-- has been silently failing on prod since at least 2026-08-12 (11k+ "relation
-- \"notifications\" does not exist" errors) - bans, warnings, review verdicts,
-- rejections, referral rewards, and pixel adjustments were never reaching a
-- player's inbox. addNotification() swallows the error by design ("best-effort"),
-- which is exactly why this went unnoticed.
CREATE TABLE IF NOT EXISTS "notifications" (
	"id" bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
	"user_id" uuid NOT NULL,
	"title" text NOT NULL,
	"body" text NOT NULL,
	"read" boolean DEFAULT false NOT NULL,
	"created_at" timestamptz DEFAULT now() NOT NULL
);
--> statement-breakpoint
DO $$ BEGIN
 ALTER TABLE "notifications" ADD CONSTRAINT "notifications_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;
EXCEPTION
 WHEN duplicate_object THEN null;
END $$;
--> statement-breakpoint
CREATE INDEX IF NOT EXISTS "notifications_user_idx" ON "notifications" ("user_id");
--> statement-breakpoint
CREATE INDEX IF NOT EXISTS "notifications_user_unread_idx" ON "notifications" ("user_id", "read");
--> statement-breakpoint
CREATE INDEX IF NOT EXISTS "notifications_created_idx" ON "notifications" ("created_at" DESC);
