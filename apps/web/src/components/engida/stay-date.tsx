import { cn } from "@/lib/utils";
import { toEthiopianDisplay } from "@engida/shared-types/ethiopic";

interface StayDateProps {
  /** ISO date string, business-date semantics (D-15) — not a timestamp */
  date: string;
  className?: string;
}

// D-10: Gregorian is the operational calendar; Ethiopian Calendar is a
// first-class *display* layer shown alongside it, never instead of it.
export function StayDate({ date, className }: StayDateProps) {
  const gregorian = new Date(date + "T00:00:00").toLocaleDateString("en-GB", {
    day: "2-digit",
    month: "short",
    year: "numeric",
  });

  return (
    <span className={cn("tabular-nums", className)}>
      {gregorian} <span className="text-text-secondary">({toEthiopianDisplay(date)})</span>
    </span>
  );
}
