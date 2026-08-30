-- Enum types (§11.1). Only the ones needed by tables in this foundation
-- increment are created here; the rest of the §11.1 catalog (folio_status,
-- payment_status, wo_status, etc.) is added alongside the migrations that
-- introduce their owning tables.
-- verify: select enum_range(null::tenant_status);

create type tenant_status as enum
  ('trial','active','past_due','suspended','cancelled','purge_scheduled','purged');

create type invitation_status as enum
  ('invited','accepted','expired','revoked');

create type member_status as enum
  ('active','suspended','deactivated');
