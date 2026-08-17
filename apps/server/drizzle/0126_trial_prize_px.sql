-- Trial ships now pay the prize AND the pixels for hours beyond the Trial's
-- minimum, instead of prize-or-all-pixels. At approval we still hold the full
-- payout (trial_held_px = total pixels), and additionally record the pixel
-- value of the Trial's minimum hours in trial_prize_px — the slice the prize
-- "buys". When the player settles:
--   * keep the prize (default) -> credit trial_held_px - trial_prize_px + prize
--   * take pixels (opt out)    -> credit trial_held_px (all), no prize
--
-- trial_prize_px is 0 for non-Trial ships and for Trials with no minimum.
--
-- Target: the orchard/CNPG database. Idempotent. Run in psql.

alter table projects add column if not exists trial_prize_px integer not null default 0;
