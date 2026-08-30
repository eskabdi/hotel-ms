-- Identity domain tables (§10 catalog rows #1-8). Conventions per §9: uuid
-- PKs, tenant_id set by trigger from JWT (never client-supplied), timestamptz
-- created_at/updated_at, soft delete via deleted_at, all FKs indexed.
--
-- Design note not fully spelled out in the blueprint's table catalog (row 5
-- "roles" only lists key/name_en/name_am/is_system/cloned_from): `roles.tenant_id`
-- is nullable — null rows are immutable system-role *templates* shared across
-- all tenants (is_system = true); a tenant's actual assignable roles are its
-- own tenant_id-scoped rows (cloned from a template, or fully custom on the
-- Pro plan per §6.1). Tenant provisioning (cloning templates into a new
-- tenant) is part of the platform/super-admin console, §27 — out of scope
-- for this foundation increment, so 0007 seeds only the templates.
--
-- verify: select count(*) from information_schema.tables where table_schema='public' and table_name in
--   ('tenants','properties','users_profile','invitations','roles','permissions','role_permissions','user_roles'); -- = 8

create table tenants (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  legal_name text,
  tin text,
  status tenant_status not null default 'trial',
  plan_id uuid, -- FK added when `plans` table lands (§10 row 47)
  trial_ends_at timestamptz,
  billing_email text,
  region text,
  zone text,
  woreda text,
  kebele text,
  default_locale text not null default 'en' check (default_locale in ('en', 'am')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create table properties (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenants (id),
  name text not null,
  code varchar(3) not null,
  business_date date not null default current_date, -- D-15: advanced only by Night Audit
  checkin_time time not null default '14:00',
  checkout_time time not null default '12:00',
  timezone text not null default 'Africa/Addis_Ababa',
  region text,
  zone text,
  woreda text,
  kebele text,
  phone text,
  invoice_seq bigint not null default 0,
  receipt_seq bigint not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  unique (tenant_id, code)
);
create index properties_tenant_id_idx on properties (tenant_id);

-- Mirrors auth.users 1:1 — global, not tenant-scoped (a user can belong to
-- multiple tenants via user_roles). Row is created by a trigger on
-- auth.users insert in a later increment (needs the Auth Hook wired first);
-- for now it's created on demand by the invite-accept flow.
create table users_profile (
  id uuid primary key references auth.users (id) on delete cascade,
  full_name text,
  phone text,
  locale text not null default 'en' check (locale in ('en', 'am')),
  avatar_path text,
  last_seen_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table invitations (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenants (id),
  email text not null,
  roles text[] not null default '{}', -- role keys, resolved against tenant's roles on accept
  property_ids uuid[] not null default '{}',
  token_hash text not null,
  status invitation_status not null default 'invited',
  expires_at timestamptz not null,
  invited_by uuid references auth.users (id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);
create index invitations_tenant_id_idx on invitations (tenant_id);

create table roles (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid references tenants (id), -- null = system template, see file header
  key text not null,
  name_en text not null,
  name_am text,
  is_system boolean not null default false,
  cloned_from uuid references roles (id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);
create index roles_tenant_id_idx on roles (tenant_id);
-- NULLs are distinct under a plain UNIQUE constraint, so template rows need
-- their own partial index to actually enforce one-key-per-tenant(-or-template).
create unique index roles_template_key_uidx on roles (key) where tenant_id is null;
create unique index roles_tenant_key_uidx on roles (tenant_id, key) where tenant_id is not null;

-- Platform-global reference data (the fixed §6.2 registry), not tenant
-- business data — seeded by migration only, never written by tenants.
create table permissions (
  id uuid primary key default gen_random_uuid(),
  key text not null unique,
  description text not null,
  category text not null,
  created_at timestamptz not null default now()
);

create table role_permissions (
  role_id uuid not null references roles (id) on delete cascade,
  permission_id uuid not null references permissions (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (role_id, permission_id)
);
create index role_permissions_permission_id_idx on role_permissions (permission_id);

-- One row = one (user, role, property-scope) grant; `status` carries the
-- §8.2 membership lifecycle (active <-> suspended -> deactivated) per grant.
create table user_roles (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenants (id),
  user_id uuid not null references auth.users (id) on delete cascade,
  role_id uuid not null references roles (id),
  property_id uuid references properties (id), -- null = all properties in the tenant
  status member_status not null default 'active',
  created_at timestamptz not null default now()
);
create index user_roles_tenant_id_idx on user_roles (tenant_id);
create index user_roles_user_id_idx on user_roles (user_id);
create index user_roles_role_id_idx on user_roles (role_id);
create unique index user_roles_scoped_uidx on user_roles (user_id, role_id, property_id) where property_id is not null;
create unique index user_roles_unscoped_uidx on user_roles (user_id, role_id) where property_id is null;

-- updated_at maintenance
create trigger touch_updated_at before update on tenants for each row execute function app.touch_updated_at();
create trigger touch_updated_at before update on properties for each row execute function app.touch_updated_at();
create trigger touch_updated_at before update on users_profile for each row execute function app.touch_updated_at();
create trigger touch_updated_at before update on invitations for each row execute function app.touch_updated_at();
create trigger touch_updated_at before update on roles for each row execute function app.touch_updated_at();

-- tenant_id is always trigger-assigned from the JWT, never client-supplied (§3b)
create trigger set_tenant_from_jwt before insert on properties for each row execute function app.set_tenant_from_jwt();
create trigger set_tenant_from_jwt before insert on invitations for each row execute function app.set_tenant_from_jwt();
create trigger set_tenant_from_jwt before insert on roles for each row execute function app.set_tenant_from_jwt();
create trigger set_tenant_from_jwt before insert on user_roles for each row execute function app.set_tenant_from_jwt();
