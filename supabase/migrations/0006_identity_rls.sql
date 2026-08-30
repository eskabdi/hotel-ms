-- app.has_perm() (§7.1) — created here, now that user_roles/role_permissions/
-- permissions exist. RLS enable+force + policies (§7.2 pattern) on every
-- identity table (D-06: no exceptions).
-- verify: select relname from pg_class where relrowsecurity and relforcerowsecurity
--   and relname in ('tenants','properties','users_profile','invitations','roles','permissions','role_permissions','user_roles'); -- = 8

create or replace function app.has_perm(p text) returns boolean
language sql stable security definer set search_path = public, app as $$
  select exists (
    select 1
    from user_roles ur
    join role_permissions rp on rp.role_id = ur.role_id
    join permissions pm on pm.id = rp.permission_id
    where ur.user_id = auth.uid()
      and ur.tenant_id = app.tenant_id()
      and ur.status = 'active'
      and pm.key = p
      and (ur.property_id is null or ur.property_id = any (app.property_ids()))
  )
$$;

-- tenants: readable only as your own tenant. No client write path — tenant
-- creation is a platform-console/service-role operation (§27), not exposed here.
alter table tenants enable row level security;
alter table tenants force row level security;
create policy tenant_self_read on tenants for select
  using (id = app.tenant_id());

-- properties: cross-property reads within a tenant limited by the
-- property_ids JWT claim (§3c), not a dedicated permission key.
alter table properties enable row level security;
alter table properties force row level security;
create policy tenant_read on properties for select
  using (tenant_id = app.tenant_id() and id = any (app.property_ids()));
create policy tenant_write on properties for insert
  with check (tenant_id = app.tenant_id() and app.has_perm('settings.property'));
create policy tenant_update on properties for update
  using (tenant_id = app.tenant_id() and app.has_perm('settings.property'))
  with check (tenant_id = app.tenant_id() and app.has_perm('settings.property'));

-- users_profile: global (no tenant_id) — self, or a colleague sharing any
-- tenant with you (needed to show names on assignment/roster screens).
alter table users_profile enable row level security;
alter table users_profile force row level security;
create policy self_or_tenantmate_read on users_profile for select
  using (
    id = auth.uid()
    or exists (
      select 1 from user_roles mine
      join user_roles theirs on theirs.tenant_id = mine.tenant_id
      where mine.user_id = auth.uid() and theirs.user_id = users_profile.id
    )
  );
create policy self_insert on users_profile for insert
  with check (id = auth.uid());
create policy self_update on users_profile for update
  using (id = auth.uid())
  with check (id = auth.uid());

alter table invitations enable row level security;
alter table invitations force row level security;
create policy tenant_read on invitations for select
  using (tenant_id = app.tenant_id() and app.has_perm('user.manage'));
create policy tenant_write on invitations for insert
  with check (tenant_id = app.tenant_id() and app.has_perm('user.manage'));
create policy tenant_update on invitations for update
  using (tenant_id = app.tenant_id() and app.has_perm('user.manage'))
  with check (tenant_id = app.tenant_id() and app.has_perm('user.manage'));

-- roles: null-tenant rows are system templates, readable by everyone (§10
-- row 5 design note in 0005); a tenant's own rows are readable within it.
-- No write policy yet — role cloning/custom roles (Pro plan, §6.1) is a
-- follow-up increment, not built here.
alter table roles enable row level security;
alter table roles force row level security;
create policy template_or_own_tenant_read on roles for select
  using (tenant_id is null or tenant_id = app.tenant_id());

-- permissions: platform-global read-only reference data.
alter table permissions enable row level security;
alter table permissions force row level security;
create policy authenticated_read on permissions for select
  to authenticated
  using (true);

-- role_permissions: readable when the owning role is visible to you.
alter table role_permissions enable row level security;
alter table role_permissions force row level security;
create policy visible_role_read on role_permissions for select
  using (
    exists (
      select 1 from roles r
      where r.id = role_permissions.role_id
        and (r.tenant_id is null or r.tenant_id = app.tenant_id())
    )
  );

alter table user_roles enable row level security;
alter table user_roles force row level security;
create policy self_or_admin_read on user_roles for select
  using (user_id = auth.uid() or (tenant_id = app.tenant_id() and app.has_perm('user.manage')));
create policy admin_write on user_roles for insert
  with check (tenant_id = app.tenant_id() and app.has_perm('user.manage'));
create policy admin_delete on user_roles for delete
  using (tenant_id = app.tenant_id() and app.has_perm('user.manage'));
