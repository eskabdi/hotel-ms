-- Custom Access Token Auth Hook (§5.4). Injects tenant_id/property_ids/roles/
-- plan/tenant_status into every issued JWT. The SQL function is created here;
-- it must additionally be *registered* as the project's Auth Hook via the
-- Supabase Dashboard (Authentication -> Hooks -> Custom Access Token) or
-- `supabase/config.toml` for local dev — that registration step is not
-- expressible in a migration and is a manual go-live checklist item (§49).
--
-- Foundation-scope simplification: a user's tenant is resolved from their
-- earliest user_roles row. Multi-tenant users and the property-picker flow
-- (D-008, §5.5 "if the user belongs to >1 property") are a follow-up
-- increment once more than one tenant/property actually exists to pick
-- between. `plan` is left null until `subscriptions` (§28) lands.
-- verify: select public.custom_access_token_hook(jsonb_build_object('user_id', gen_random_uuid(), 'claims', '{}'::jsonb));
--   -- should return the event with tenant_id/property_ids/roles/plan/tenant_status all null/empty, no error.

create or replace function public.custom_access_token_hook(event jsonb) returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  claims jsonb;
  v_user_id uuid := (event ->> 'user_id')::uuid;
  v_tenant_id uuid;
  v_property_ids uuid[];
  v_roles text[];
  v_tenant_status text;
begin
  select ur.tenant_id into v_tenant_id
  from user_roles ur
  where ur.user_id = v_user_id and ur.status = 'active'
  order by ur.created_at
  limit 1;

  if v_tenant_id is not null then
    select coalesce(array_agg(distinct ur.property_id) filter (where ur.property_id is not null), '{}')
      into v_property_ids
    from user_roles ur
    where ur.user_id = v_user_id and ur.tenant_id = v_tenant_id and ur.status = 'active';

    select coalesce(array_agg(distinct r.key), '{}')
      into v_roles
    from user_roles ur
    join roles r on r.id = ur.role_id
    where ur.user_id = v_user_id and ur.tenant_id = v_tenant_id and ur.status = 'active';

    select t.status::text into v_tenant_status from tenants t where t.id = v_tenant_id;
  end if;

  claims := coalesce(event -> 'claims', '{}'::jsonb);
  claims := jsonb_set(claims, '{tenant_id}', to_jsonb(v_tenant_id));
  claims := jsonb_set(claims, '{property_ids}', coalesce(to_jsonb(v_property_ids), '[]'::jsonb));
  claims := jsonb_set(claims, '{roles}', coalesce(to_jsonb(v_roles), '[]'::jsonb));
  claims := jsonb_set(claims, '{plan}', 'null'::jsonb);
  claims := jsonb_set(claims, '{tenant_status}', to_jsonb(v_tenant_status));

  return jsonb_set(event, '{claims}', claims);
end;
$$;

grant usage on schema public to supabase_auth_admin;
grant execute on function public.custom_access_token_hook to supabase_auth_admin;
revoke execute on function public.custom_access_token_hook from authenticated, anon, public;

grant select on user_roles, roles, tenants to supabase_auth_admin;
