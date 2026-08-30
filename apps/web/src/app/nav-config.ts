// Top-level nav map (§35). Every item beyond Dashboard is a disabled
// "coming soon" placeholder until its feature module lands — this increment
// only builds the shell, not the modules.
export interface NavItem {
  key: string;
  labelKey: string;
  path: string;
  /** roles that see this item; empty = all authenticated staff */
  roles?: string[];
  enabled: boolean;
}

export const NAV_ITEMS: NavItem[] = [
  { key: "dashboard", labelKey: "nav.dashboard", path: "/", enabled: true },
  { key: "frontdesk", labelKey: "nav.frontDesk", path: "/front-desk", enabled: false },
  { key: "reservations", labelKey: "nav.reservations", path: "/reservations", enabled: false },
  { key: "guests", labelKey: "nav.guests", path: "/guests", enabled: false },
  { key: "housekeeping", labelKey: "nav.housekeeping", path: "/housekeeping", enabled: false },
  { key: "maintenance", labelKey: "nav.maintenance", path: "/maintenance", enabled: false },
  { key: "pos", labelKey: "nav.pos", path: "/pos", enabled: false },
  { key: "billing", labelKey: "nav.billing", path: "/billing", enabled: false },
  { key: "rates", labelKey: "nav.rates", path: "/rates", enabled: false },
  { key: "reports", labelKey: "nav.reports", path: "/reports", enabled: false },
  { key: "channels", labelKey: "nav.channels", path: "/channels", enabled: false },
  { key: "settings", labelKey: "nav.settings", path: "/settings", enabled: false },
];

export const PLATFORM_NAV_ROLES = ["platform_admin", "platform_support"];
