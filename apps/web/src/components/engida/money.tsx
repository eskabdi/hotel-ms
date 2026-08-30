import { cn } from "@/lib/utils";

interface MoneyProps {
  /** amount in ETB, as stored (numeric(14,2)) */
  amount: number;
  className?: string;
}

const formatter = new Intl.NumberFormat("en-ET", {
  minimumFractionDigits: 2,
  maximumFractionDigits: 2,
});

// D-09: ETB is the sole functional/ledger currency — never render `$` anywhere.
// Always render money through this component so that rule can't be missed ad hoc.
export function Money({ amount, className }: MoneyProps) {
  return <span className={cn("tabular-nums", className)}>ETB {formatter.format(amount)}</span>;
}
