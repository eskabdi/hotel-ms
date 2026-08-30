-- app schema + JWT-claim helper functions (§7.1, verbatim from the blueprint).
-- verify: select app.tenant_id(), app.property_ids(); -- both null/empty outside a request context, no error.

create schema if not exists app;

create or replace function app.tenant_id() returns uuid
language sql stable as $$
  select nullif(current_setting('request.jwt.claims', true)::jsonb->>'tenant_id','')::uuid
$$;

create or replace function app.property_ids() returns uuid[]
language sql stable as $$
  select coalesce(
    (select array_agg(value::uuid)
       from jsonb_array_elements_text(
         current_setting('request.jwt.claims', true)::jsonb->'property_ids')),
    '{}')
$$;

-- app.has_perm() is created in 0006_identity_rls.sql instead of here: it
-- references user_roles/role_permissions/permissions (0005_identity_tables.sql),
-- and Postgres validates a LANGUAGE SQL function body against real catalog
-- objects at CREATE FUNCTION time, so it can't be defined before those tables
-- exist.
