// Single source of truth for the permission registry (§6.2 of
// docs/engida-hms-master-blueprint-v1.md). Mirrored into migration
// 0007_seed_permissions_roles.sql (seed data) and consumed by the UI for
// cosmetic gating only (D-23: the client never decides authorization — every
// RLS policy and RPC re-checks `app.has_perm()` server-side).
//
// `owner` implicitly has every permission and is omitted from defaultRoles.

export type RoleCode =
  | "owner"
  | "manager"
  | "front_desk"
  | "night_auditor"
  | "hk_supervisor"
  | "housekeeper"
  | "maintenance"
  | "accountant"
  | "pos_staff"
  | "pos_supervisor"
  | "guest"
  | "platform_admin"
  | "platform_support";

export interface PermissionDef {
  key: string;
  description: string;
  category: string;
  /** Roles granted this permission by default, beyond `owner` (who has all). */
  defaultRoles: RoleCode[];
}

export const PERMISSIONS: readonly PermissionDef[] = [
  { key: "reservation.read", description: "View reservations & calendar", category: "reservation", defaultRoles: ["manager", "front_desk", "night_auditor", "hk_supervisor", "accountant"] },
  { key: "reservation.create", description: "Create bookings/holds/walk-ins", category: "reservation", defaultRoles: ["manager", "front_desk", "night_auditor"] },
  { key: "reservation.update", description: "Edit dates, guests, notes", category: "reservation", defaultRoles: ["manager", "front_desk", "night_auditor"] },
  { key: "reservation.cancel", description: "Cancel within policy", category: "reservation", defaultRoles: ["manager", "front_desk", "night_auditor"] },
  { key: "reservation.cancel.override", description: "Cancel outside policy / waive fee", category: "reservation", defaultRoles: ["manager"] },
  { key: "reservation.rate_override", description: "Manual rate at booking (reason required)", category: "reservation", defaultRoles: ["manager"] },
  { key: "reservation.noshow", description: "Mark no-show manually", category: "reservation", defaultRoles: ["manager", "night_auditor"] },
  { key: "reservation.reinstate", description: "Reinstate cancelled/no-show/checked-out", category: "reservation", defaultRoles: ["manager"] },

  { key: "frontdesk.checkin", description: "Perform check-in", category: "frontdesk", defaultRoles: ["manager", "front_desk", "night_auditor"] },
  { key: "frontdesk.checkout", description: "Perform check-out", category: "frontdesk", defaultRoles: ["manager", "front_desk", "night_auditor"] },
  { key: "frontdesk.room_move", description: "Move in-house guest", category: "frontdesk", defaultRoles: ["manager", "front_desk", "night_auditor"] },
  { key: "frontdesk.checkout_with_balance", description: "Check out with nonzero balance", category: "frontdesk", defaultRoles: ["manager"] },

  { key: "room.read", description: "View rooms", category: "room", defaultRoles: ["manager", "front_desk", "night_auditor", "hk_supervisor", "housekeeper", "maintenance", "accountant"] },
  { key: "room.manage", description: "Edit rooms & types", category: "room", defaultRoles: ["manager"] },
  { key: "room.ooo", description: "Set Out-of-Order / Out-of-Service", category: "room", defaultRoles: ["manager", "hk_supervisor", "maintenance"] },

  { key: "rate.read", description: "View rates", category: "rate", defaultRoles: ["manager", "front_desk", "accountant"] },
  { key: "rate.manage", description: "Edit rate plans, seasons, restrictions", category: "rate", defaultRoles: ["manager"] },

  { key: "hk.read", description: "See HK board", category: "housekeeping", defaultRoles: ["manager", "front_desk", "hk_supervisor", "housekeeper"] },
  { key: "hk.update_status", description: "Change room clean status", category: "housekeeping", defaultRoles: ["housekeeper", "hk_supervisor", "front_desk"] },
  { key: "hk.assign", description: "Assign HK tasks", category: "housekeeping", defaultRoles: ["hk_supervisor", "manager"] },
  { key: "hk.inspect", description: "Pass/fail inspection", category: "housekeeping", defaultRoles: ["hk_supervisor", "manager"] },

  { key: "mx.read", description: "View work orders", category: "maintenance", defaultRoles: ["maintenance", "hk_supervisor", "manager"] },
  { key: "mx.create", description: "Raise work orders", category: "maintenance", defaultRoles: ["manager", "front_desk", "night_auditor", "hk_supervisor", "housekeeper", "maintenance", "accountant", "pos_staff", "pos_supervisor"] },
  { key: "mx.assign", description: "Assign work orders", category: "maintenance", defaultRoles: ["manager", "hk_supervisor"] },
  { key: "mx.close", description: "Verify-close work orders", category: "maintenance", defaultRoles: ["manager"] },

  { key: "folio.read", description: "View folios", category: "folio", defaultRoles: ["front_desk", "accountant", "manager"] },
  { key: "folio.post", description: "Post charges", category: "folio", defaultRoles: ["front_desk", "night_auditor", "pos_staff", "pos_supervisor", "accountant"] },
  { key: "folio.transfer", description: "Move charges between folios", category: "folio", defaultRoles: ["front_desk", "accountant", "manager"] },
  { key: "folio.split", description: "Split folios", category: "folio", defaultRoles: ["front_desk", "accountant", "manager"] },
  { key: "folio.void_sameday", description: "Void a same-business-date line (reason)", category: "folio", defaultRoles: ["front_desk", "accountant", "manager"] },
  { key: "folio.adjust", description: "Post-audit correction/allowance (reason)", category: "folio", defaultRoles: ["accountant", "manager"] },
  { key: "folio.reopen", description: "Reopen a settled/closed folio", category: "folio", defaultRoles: ["manager"] },

  { key: "payment.take", description: "Record cash/transfer, initiate Chapa/Telebirr", category: "payment", defaultRoles: ["front_desk", "night_auditor", "accountant", "pos_supervisor"] },
  { key: "payment.refund", description: "Refund (self-serve under threshold, else approval)", category: "payment", defaultRoles: ["accountant", "manager"] },

  { key: "invoice.issue", description: "Issue fiscal invoice", category: "invoice", defaultRoles: ["front_desk", "accountant", "manager"] },
  { key: "invoice.credit_note", description: "Issue credit note", category: "invoice", defaultRoles: ["accountant", "manager"] },

  { key: "cashier.shift", description: "Open/close own cashier shift", category: "cashier", defaultRoles: ["front_desk", "accountant", "pos_supervisor", "night_auditor"] },
  { key: "cashier.shift.review", description: "Review/approve over-short", category: "cashier", defaultRoles: ["accountant", "manager"] },

  { key: "audit.run", description: "Execute night audit", category: "audit", defaultRoles: ["night_auditor", "manager"] },

  { key: "pos.sell", description: "Ticket operations", category: "pos", defaultRoles: ["pos_staff", "pos_supervisor"] },
  { key: "pos.void", description: "Void ticket lines", category: "pos", defaultRoles: ["pos_supervisor", "manager"] },
  { key: "pos.dayclose", description: "Close POS day", category: "pos", defaultRoles: ["pos_supervisor", "manager"] },

  { key: "guest.read", description: "View guest profiles", category: "guest", defaultRoles: ["front_desk", "manager", "accountant", "night_auditor"] },
  { key: "guest.manage", description: "Edit guest profiles", category: "guest", defaultRoles: ["front_desk", "manager"] },
  { key: "guest.merge", description: "Merge duplicate guests", category: "guest", defaultRoles: ["manager"] },
  { key: "guest.dnr", description: "Set/lift Do-Not-Rent flags", category: "guest", defaultRoles: ["manager"] },
  { key: "guest.export", description: "Export guest data", category: "guest", defaultRoles: ["manager"] },
  { key: "guest.anonymize", description: "Anonymize guest data", category: "guest", defaultRoles: ["manager"] },

  { key: "group.manage", description: "Blocks, allotments, rooming lists", category: "group", defaultRoles: ["manager"] },

  { key: "channel.manage", description: "iCal links, channel mapping, sync queue", category: "channel", defaultRoles: ["manager"] },

  { key: "report.operational", description: "Operational reports", category: "report", defaultRoles: ["manager", "front_desk", "hk_supervisor"] },
  { key: "report.financial", description: "Revenue & cashier reports", category: "report", defaultRoles: ["accountant", "manager"] },

  { key: "settings.property", description: "Edit property configuration", category: "settings", defaultRoles: ["manager"] },
  { key: "settings.tax", description: "Edit tax rates", category: "settings", defaultRoles: [] },
  { key: "settings.billing_providers", description: "Edit payment provider keys", category: "settings", defaultRoles: [] },

  { key: "user.manage", description: "Invite/deactivate users", category: "admin", defaultRoles: ["manager"] },
  { key: "role.manage", description: "Edit custom roles (Pro plan)", category: "admin", defaultRoles: [] },

  { key: "audit_log.read", description: "View audit trail", category: "admin", defaultRoles: ["manager", "accountant"] },

  { key: "notification.templates", description: "Edit message templates", category: "admin", defaultRoles: ["manager"] },

  { key: "platform.tenants", description: "Tenant CRUD", category: "platform", defaultRoles: ["platform_admin"] },
  { key: "platform.plans", description: "Plan & pricing management", category: "platform", defaultRoles: ["platform_admin"] },
  { key: "platform.impersonate", description: "Impersonate a tenant user", category: "platform", defaultRoles: ["platform_admin", "platform_support"] },
  { key: "platform.announcements", description: "Post platform announcements", category: "platform", defaultRoles: ["platform_admin"] },
  { key: "platform.backups", description: "Manage backups", category: "platform", defaultRoles: ["platform_admin"] },
  { key: "platform.flags", description: "Manage feature flags", category: "platform", defaultRoles: ["platform_admin"] },
] as const;

export type PermissionKey = (typeof PERMISSIONS)[number]["key"];

export const PERMISSION_KEYS: readonly PermissionKey[] = PERMISSIONS.map((p) => p.key);
