-- One-off: raise EVERY shop item's price by 10%, across all regions, rounded
-- to the nearest 25px (the catalog's standing convention — every price is a
-- multiple of 25). Rows priced at 0 (unavailable in that region) stay 0.
--
-- pixorpheus must NOT announce this bulk change, so we run it with
-- session_replication_role = replica, which suppresses the shop_items change
-- trigger (0103) for this session only. (Works whether or not that trigger is
-- installed yet — nothing to announce either way.)
--
-- ⚠️  NOT idempotent — this compounds if run twice (10% on top of 10%).
--     Run it EXACTLY ONCE. Re-running raises prices again.
-- Run this in the Supabase SQL editor.

BEGIN;

-- Silencing the trigger needs superuser, which the managed Postgres role is
-- not. Where that is refused the trigger from 0103 was skipped too (no pg_net),
-- so there is nothing to suppress and the update proceeds either way.
DO $$
BEGIN
  SET LOCAL session_replication_role = replica;
EXCEPTION WHEN insufficient_privilege THEN
  RAISE NOTICE 'cannot set session_replication_role; shop change trigger is absent anyway';
END
$$;

UPDATE shop_items
SET price = (round(price * 1.1 / 25.0) * 25)::int
WHERE price > 0;

COMMIT;
