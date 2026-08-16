-- Trial ships now pay out one way or the other, not both. A project shipped for
-- a Trial has its pixel payout *held* at approval instead of credited, and the
-- player picks: take the Trial's prize (a free shop order, pixels forfeited) or
-- take the pixels (no prize). Whichever they skip is gone.
--
-- trial_reward_choice: '' = not a Trial ship / nothing to choose,
-- 'pending' = approved and waiting on the player, 'item' / 'pixels' = settled.
-- trial_held_px is what the payout math produced at approval, kept so the
-- pixels branch credits exactly what was withheld rather than recomputing it
-- against rates that may have moved since.
alter table projects add column if not exists trial_reward_choice text not null default '';
--> statement-breakpoint
alter table projects add column if not exists trial_held_px integer not null default 0;
--> statement-breakpoint
create index if not exists projects_trial_reward_choice_idx
  on projects (trial_reward_choice)
  where trial_reward_choice = 'pending';
--> statement-breakpoint

-- Over-budget flag for fulfillment. A player's pixels convert to a fixed dollar
-- budget (packages/config economy.pixelValueUsd); if a fulfiller can't source
-- the item at or under it, they flag the order instead of placing it and an
-- owner decides what to do.
alter table shop_orders add column if not exists flagged_at timestamptz;
--> statement-breakpoint
alter table shop_orders add column if not exists flagged_by text not null default '';
--> statement-breakpoint
alter table shop_orders add column if not exists flag_note text not null default '';
