-- Extensions required by the identity/inventory/booking schema (§9, §11.2).
-- verify: select 1 from pg_extension where extname in ('pgcrypto','btree_gist') having count(*) = 2;

create extension if not exists pgcrypto;   -- gen_random_uuid()
create extension if not exists btree_gist; -- GiST exclusion constraints (double-booking guard, §11.2)
