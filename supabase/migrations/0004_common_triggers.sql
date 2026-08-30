-- Generic trigger functions (§9, §11.3). Trigger bodies aren't bound to a
-- specific table's columns until CREATE TRIGGER attaches them, so these are
-- safe to define before any business tables exist.
-- verify: select proname from pg_proc where pronamespace = 'app'::regnamespace and proname in ('touch_updated_at','set_tenant_from_jwt');

create or replace function app.touch_updated_at() returns trigger
language plpgsql as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

-- Unconditionally overwrites tenant_id from the JWT on every insert — the
-- client cannot spoof it (§3b). During migrations/seed (no request JWT
-- context) app.tenant_id() is null, which is intentional for seeding
-- tenant-agnostic template rows (e.g. system role templates, §29.5 note
-- in 0005_identity_tables.sql).
create or replace function app.set_tenant_from_jwt() returns trigger
language plpgsql as $$
begin
  new.tenant_id := app.tenant_id();
  return new;
end;
$$;
