// Feature flag registry stub (§29 of docs/engida-hms-master-blueprint-v1.md).
// The full ~40-row config-key table is out of scope for this foundation
// increment; keys are added here as each feature module lands.

export type FeatureFlagKey =
  | "res.fd_rate_override"
  | "group.fd_manage"
  | "hk.restrict_to_assigned"
  | "billing.fx_reference_display"
  | "module.pos";

export const FEATURE_FLAG_DEFAULTS: Record<FeatureFlagKey, boolean> = {
  "res.fd_rate_override": false,
  "group.fd_manage": false,
  "hk.restrict_to_assigned": false,
  "billing.fx_reference_display": false,
  "module.pos": false,
};
