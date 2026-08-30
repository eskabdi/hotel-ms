import { cn } from "@/lib/utils";

// Fixed status-color contract (§34) — resolved against the Z Shop-derived
// tokens per the plan's color mapping table, not redefined ad hoc per screen.
const STATUS_STYLES = {
  hold: "bg-status-hold/20 text-text-primary",
  confirmed: "bg-status-confirmed/15 text-status-confirmed",
  checked_in: "bg-status-inhouse/15 text-status-inhouse",
  checked_out: "bg-status-checkedout/15 text-status-checkedout",
  cancelled: "bg-status-cancelled/20 text-text-secondary line-through",
  no_show: "bg-status-noshow/15 text-status-noshow",
  expired: "bg-status-cancelled/20 text-text-secondary",
  ooo: "bg-status-ooo/15 text-status-ooo",
  oos: "bg-status-oos/20 text-text-primary",
  vacant_dirty: "bg-status-dirty/15 text-status-dirty",
  vacant_clean: "bg-status-clean/20 text-text-primary",
  vacant_inspected: "bg-status-inspected/15 text-status-inspected",
  occupied_dirty: "bg-status-dirty/15 text-status-dirty",
  occupied_clean: "bg-status-clean/20 text-text-primary",
} as const;

export type StatusKey = keyof typeof STATUS_STYLES;

interface StatusPillProps {
  status: StatusKey;
  label: string;
  className?: string;
}

export function StatusPill({ status, label, className }: StatusPillProps) {
  return (
    <span className={cn("inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-medium", STATUS_STYLES[status], className)}>
      {label}
    </span>
  );
}
