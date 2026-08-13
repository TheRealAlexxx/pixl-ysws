-- Ridit + Gabin (Slack, 2026-08-13): clear the old vault levels and replace
-- them with the real Chapter 1 community goal. 7500 RE is the target for the
-- chapter's 3-week window (500h shipped, averaged across the 5-25 RE/hr tier
-- range) — hitting it closes Chapter 1 and opens Chapter 2.
delete from vault_levels;

insert into vault_levels (level, energy_required, title, blurb, rewards, position) values
  (1, 7500, 'The Core Awakens', 'The Core comes fully online. Chapter 1 closes, and the way into Chapter 2 opens.',
    '[{"icon":"⚡","label":"Core Awakened title"},{"icon":"🌅","label":"Chapter 1 banner"}]'::jsonb, 1)
on conflict (level) do nothing;
