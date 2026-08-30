-- Seeds the platform-global `permissions` registry and the system `roles`
-- templates (tenant_id null) with their default role_permissions mapping.
-- Mirrors packages/shared-types/src/permissions.ts exactly — keep both in
-- sync when the registry changes (§6.2).
-- verify: select count(*) from permissions; -- = 55
-- verify: select count(*) from roles where tenant_id is null; -- = 13

insert into permissions (key, description, category) values
  ('reservation.read', 'View reservations & calendar', 'reservation'),
  ('reservation.create', 'Create bookings/holds/walk-ins', 'reservation'),
  ('reservation.update', 'Edit dates, guests, notes', 'reservation'),
  ('reservation.cancel', 'Cancel within policy', 'reservation'),
  ('reservation.cancel.override', 'Cancel outside policy / waive fee', 'reservation'),
  ('reservation.rate_override', 'Manual rate at booking (reason required)', 'reservation'),
  ('reservation.noshow', 'Mark no-show manually', 'reservation'),
  ('reservation.reinstate', 'Reinstate cancelled/no-show/checked-out', 'reservation'),

  ('frontdesk.checkin', 'Perform check-in', 'frontdesk'),
  ('frontdesk.checkout', 'Perform check-out', 'frontdesk'),
  ('frontdesk.room_move', 'Move in-house guest', 'frontdesk'),
  ('frontdesk.checkout_with_balance', 'Check out with nonzero balance', 'frontdesk'),

  ('room.read', 'View rooms', 'room'),
  ('room.manage', 'Edit rooms & types', 'room'),
  ('room.ooo', 'Set Out-of-Order / Out-of-Service', 'room'),

  ('rate.read', 'View rates', 'rate'),
  ('rate.manage', 'Edit rate plans, seasons, restrictions', 'rate'),

  ('hk.read', 'See HK board', 'housekeeping'),
  ('hk.update_status', 'Change room clean status', 'housekeeping'),
  ('hk.assign', 'Assign HK tasks', 'housekeeping'),
  ('hk.inspect', 'Pass/fail inspection', 'housekeeping'),

  ('mx.read', 'View work orders', 'maintenance'),
  ('mx.create', 'Raise work orders', 'maintenance'),
  ('mx.assign', 'Assign work orders', 'maintenance'),
  ('mx.close', 'Verify-close work orders', 'maintenance'),

  ('folio.read', 'View folios', 'folio'),
  ('folio.post', 'Post charges', 'folio'),
  ('folio.transfer', 'Move charges between folios', 'folio'),
  ('folio.split', 'Split folios', 'folio'),
  ('folio.void_sameday', 'Void a same-business-date line (reason)', 'folio'),
  ('folio.adjust', 'Post-audit correction/allowance (reason)', 'folio'),
  ('folio.reopen', 'Reopen a settled/closed folio', 'folio'),

  ('payment.take', 'Record cash/transfer, initiate Chapa/Telebirr', 'payment'),
  ('payment.refund', 'Refund (self-serve under threshold, else approval)', 'payment'),

  ('invoice.issue', 'Issue fiscal invoice', 'invoice'),
  ('invoice.credit_note', 'Issue credit note', 'invoice'),

  ('cashier.shift', 'Open/close own cashier shift', 'cashier'),
  ('cashier.shift.review', 'Review/approve over-short', 'cashier'),

  ('audit.run', 'Execute night audit', 'audit'),

  ('pos.sell', 'Ticket operations', 'pos'),
  ('pos.void', 'Void ticket lines', 'pos'),
  ('pos.dayclose', 'Close POS day', 'pos'),

  ('guest.read', 'View guest profiles', 'guest'),
  ('guest.manage', 'Edit guest profiles', 'guest'),
  ('guest.merge', 'Merge duplicate guests', 'guest'),
  ('guest.dnr', 'Set/lift Do-Not-Rent flags', 'guest'),
  ('guest.export', 'Export guest data', 'guest'),
  ('guest.anonymize', 'Anonymize guest data', 'guest'),

  ('group.manage', 'Blocks, allotments, rooming lists', 'group'),

  ('channel.manage', 'iCal links, channel mapping, sync queue', 'channel'),

  ('report.operational', 'Operational reports', 'report'),
  ('report.financial', 'Revenue & cashier reports', 'report'),

  ('settings.property', 'Edit property configuration', 'settings'),
  ('settings.tax', 'Edit tax rates', 'settings'),
  ('settings.billing_providers', 'Edit payment provider keys', 'settings'),

  ('user.manage', 'Invite/deactivate users', 'admin'),
  ('role.manage', 'Edit custom roles (Pro plan)', 'admin'),

  ('audit_log.read', 'View audit trail', 'admin'),

  ('notification.templates', 'Edit message templates', 'admin'),

  ('platform.tenants', 'Tenant CRUD', 'platform'),
  ('platform.plans', 'Plan & pricing management', 'platform'),
  ('platform.impersonate', 'Impersonate a tenant user', 'platform'),
  ('platform.announcements', 'Post platform announcements', 'platform'),
  ('platform.backups', 'Manage backups', 'platform'),
  ('platform.flags', 'Manage feature flags', 'platform');

insert into roles (key, name_en, is_system) values
  ('owner', 'Owner', true),
  ('manager', 'Manager', true),
  ('front_desk', 'Front Desk', true),
  ('night_auditor', 'Night Auditor', true),
  ('hk_supervisor', 'Housekeeping Supervisor', true),
  ('housekeeper', 'Housekeeper', true),
  ('maintenance', 'Maintenance', true),
  ('accountant', 'Accountant', true),
  ('pos_staff', 'POS Staff', true),
  ('pos_supervisor', 'POS Supervisor', true),
  ('guest', 'Guest', true),
  ('platform_admin', 'Platform Admin', true),
  ('platform_support', 'Platform Support', true);

-- owner implicitly has every permission (§6.1)
insert into role_permissions (role_id, permission_id)
select r.id, p.id
from roles r
cross join permissions p
where r.key = 'owner' and r.tenant_id is null;

insert into role_permissions (role_id, permission_id)
select r.id, p.id
from (values
  ('manager', 'reservation.read'), ('front_desk', 'reservation.read'), ('night_auditor', 'reservation.read'), ('hk_supervisor', 'reservation.read'), ('accountant', 'reservation.read'),
  ('manager', 'reservation.create'), ('front_desk', 'reservation.create'), ('night_auditor', 'reservation.create'),
  ('manager', 'reservation.update'), ('front_desk', 'reservation.update'), ('night_auditor', 'reservation.update'),
  ('manager', 'reservation.cancel'), ('front_desk', 'reservation.cancel'), ('night_auditor', 'reservation.cancel'),
  ('manager', 'reservation.cancel.override'),
  ('manager', 'reservation.rate_override'),
  ('manager', 'reservation.noshow'), ('night_auditor', 'reservation.noshow'),
  ('manager', 'reservation.reinstate'),

  ('manager', 'frontdesk.checkin'), ('front_desk', 'frontdesk.checkin'), ('night_auditor', 'frontdesk.checkin'),
  ('manager', 'frontdesk.checkout'), ('front_desk', 'frontdesk.checkout'), ('night_auditor', 'frontdesk.checkout'),
  ('manager', 'frontdesk.room_move'), ('front_desk', 'frontdesk.room_move'), ('night_auditor', 'frontdesk.room_move'),
  ('manager', 'frontdesk.checkout_with_balance'),

  ('manager', 'room.read'), ('front_desk', 'room.read'), ('night_auditor', 'room.read'), ('hk_supervisor', 'room.read'), ('housekeeper', 'room.read'), ('maintenance', 'room.read'), ('accountant', 'room.read'),
  ('manager', 'room.manage'),
  ('manager', 'room.ooo'), ('hk_supervisor', 'room.ooo'), ('maintenance', 'room.ooo'),

  ('manager', 'rate.read'), ('front_desk', 'rate.read'), ('accountant', 'rate.read'),
  ('manager', 'rate.manage'),

  ('manager', 'hk.read'), ('front_desk', 'hk.read'), ('hk_supervisor', 'hk.read'), ('housekeeper', 'hk.read'),
  ('housekeeper', 'hk.update_status'), ('hk_supervisor', 'hk.update_status'), ('front_desk', 'hk.update_status'),
  ('hk_supervisor', 'hk.assign'), ('manager', 'hk.assign'),
  ('hk_supervisor', 'hk.inspect'), ('manager', 'hk.inspect'),

  ('maintenance', 'mx.read'), ('hk_supervisor', 'mx.read'), ('manager', 'mx.read'),
  ('manager', 'mx.create'), ('front_desk', 'mx.create'), ('night_auditor', 'mx.create'), ('hk_supervisor', 'mx.create'), ('housekeeper', 'mx.create'), ('maintenance', 'mx.create'), ('accountant', 'mx.create'), ('pos_staff', 'mx.create'), ('pos_supervisor', 'mx.create'),
  ('manager', 'mx.assign'), ('hk_supervisor', 'mx.assign'),
  ('manager', 'mx.close'),

  ('front_desk', 'folio.read'), ('accountant', 'folio.read'), ('manager', 'folio.read'),
  ('front_desk', 'folio.post'), ('night_auditor', 'folio.post'), ('pos_staff', 'folio.post'), ('pos_supervisor', 'folio.post'), ('accountant', 'folio.post'),
  ('front_desk', 'folio.transfer'), ('accountant', 'folio.transfer'), ('manager', 'folio.transfer'),
  ('front_desk', 'folio.split'), ('accountant', 'folio.split'), ('manager', 'folio.split'),
  ('front_desk', 'folio.void_sameday'), ('accountant', 'folio.void_sameday'), ('manager', 'folio.void_sameday'),
  ('accountant', 'folio.adjust'), ('manager', 'folio.adjust'),
  ('manager', 'folio.reopen'),

  ('front_desk', 'payment.take'), ('night_auditor', 'payment.take'), ('accountant', 'payment.take'), ('pos_supervisor', 'payment.take'),
  ('accountant', 'payment.refund'), ('manager', 'payment.refund'),

  ('front_desk', 'invoice.issue'), ('accountant', 'invoice.issue'), ('manager', 'invoice.issue'),
  ('accountant', 'invoice.credit_note'), ('manager', 'invoice.credit_note'),

  ('front_desk', 'cashier.shift'), ('accountant', 'cashier.shift'), ('pos_supervisor', 'cashier.shift'), ('night_auditor', 'cashier.shift'),
  ('accountant', 'cashier.shift.review'), ('manager', 'cashier.shift.review'),

  ('night_auditor', 'audit.run'), ('manager', 'audit.run'),

  ('pos_staff', 'pos.sell'), ('pos_supervisor', 'pos.sell'),
  ('pos_supervisor', 'pos.void'), ('manager', 'pos.void'),
  ('pos_supervisor', 'pos.dayclose'), ('manager', 'pos.dayclose'),

  ('front_desk', 'guest.read'), ('manager', 'guest.read'), ('accountant', 'guest.read'), ('night_auditor', 'guest.read'),
  ('front_desk', 'guest.manage'), ('manager', 'guest.manage'),
  ('manager', 'guest.merge'),
  ('manager', 'guest.dnr'),
  ('manager', 'guest.export'),
  ('manager', 'guest.anonymize'),

  ('manager', 'group.manage'),

  ('manager', 'channel.manage'),

  ('manager', 'report.operational'), ('front_desk', 'report.operational'), ('hk_supervisor', 'report.operational'),
  ('accountant', 'report.financial'), ('manager', 'report.financial'),

  ('manager', 'settings.property'),

  ('manager', 'user.manage'),

  ('manager', 'audit_log.read'), ('accountant', 'audit_log.read'),

  ('manager', 'notification.templates'),

  ('platform_admin', 'platform.tenants'),
  ('platform_admin', 'platform.plans'),
  ('platform_admin', 'platform.impersonate'), ('platform_support', 'platform.impersonate'),
  ('platform_admin', 'platform.announcements'),
  ('platform_admin', 'platform.backups'),
  ('platform_admin', 'platform.flags')
) as pairs (role_key, permission_key)
join roles r on r.key = pairs.role_key and r.tenant_id is null
join permissions p on p.key = pairs.permission_key;
