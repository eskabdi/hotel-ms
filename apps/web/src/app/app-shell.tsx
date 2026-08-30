import { type ReactNode } from "react";
import { useTranslation } from "react-i18next";
import { Link } from "@tanstack/react-router";
import { useSession } from "@/lib/session-provider";
import { supabase } from "@/lib/supabase";
import { NAV_ITEMS, PLATFORM_NAV_ROLES } from "./nav-config";
import { Button } from "@/components/ui/button";
import { cn } from "@/lib/utils";

export function AppShell({ children }: { children: ReactNode }) {
  const { t } = useTranslation();
  const { session, claims, hasRole } = useSession();
  const isPlatformStaff = PLATFORM_NAV_ROLES.some((r) => hasRole(r));

  return (
    <div className="flex min-h-screen bg-surface">
      <aside className="flex w-60 flex-col border-r border-border bg-surface">
        <div className="flex h-16 items-center px-4 text-lg font-semibold text-primary">
          {t("app.name")}
        </div>
        <nav className="flex-1 space-y-1 px-2">
          {NAV_ITEMS.map((item) => (
            <NavLink key={item.key} to={item.path} enabled={item.enabled} label={t(item.labelKey)} comingSoon={t("common.comingSoon")} />
          ))}
          {isPlatformStaff && (
            <NavLink to="/platform" enabled label={t("nav.platform")} comingSoon="" />
          )}
        </nav>
      </aside>

      <div className="flex flex-1 flex-col">
        <header className="flex h-16 items-center justify-between border-b border-border bg-surface px-6">
          <div className="text-sm text-text-secondary">
            {claims?.tenant_id ? `Tenant: ${claims.tenant_id.slice(0, 8)}…` : "No tenant"}
          </div>
          <div className="flex items-center gap-4">
            <span className="text-sm text-text-secondary">{session?.user.email}</span>
            <Button variant="secondary" size="sm" onClick={() => supabase.auth.signOut()}>
              {t("auth.signOut")}
            </Button>
          </div>
        </header>
        <main className="flex-1 p-6">{children}</main>
      </div>
    </div>
  );
}

function NavLink({ to, enabled, label, comingSoon }: { to: string; enabled: boolean; label: string; comingSoon: string }) {
  if (!enabled) {
    return (
      <div
        className="flex cursor-not-allowed items-center justify-between rounded px-3 py-2 text-sm text-text-secondary opacity-60"
        title={comingSoon}
      >
        {label}
      </div>
    );
  }

  return (
    <Link
      to={to}
      className={cn("block rounded px-3 py-2 text-sm text-text-primary hover:bg-surface-muted")}
      activeProps={{ className: "bg-surface-muted font-medium" }}
    >
      {label}
    </Link>
  );
}
