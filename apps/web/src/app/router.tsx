import { Outlet, Navigate, createRootRoute, createRoute, createRouter } from "@tanstack/react-router";
import { useSession } from "@/lib/session-provider";
import { AppShell } from "./app-shell";
import { LoginPage } from "./login-page";
import { DashboardPage } from "./dashboard-page";
import { PlatformPage } from "./platform-page";
import { PLATFORM_NAV_ROLES } from "./nav-config";

const rootRoute = createRootRoute({
  component: () => <Outlet />,
});

const loginRoute = createRoute({
  getParentRoute: () => rootRoute,
  path: "/login",
  component: LoginPage,
});

// Route-guard: session state lives in React context (SessionProvider), so the
// guard is a component wrapper rather than a router `beforeLoad` — keeps a
// single source of session truth (§5.3) instead of duplicating it into router
// context.
// eslint-disable-next-line react-refresh/only-export-components -- route tree colocated by design (§45)
function AuthenticatedLayout() {
  const { session, loading } = useSession();

  if (loading) {
    return <div className="flex min-h-screen items-center justify-center text-text-secondary">Loading…</div>;
  }

  if (!session) {
    return <Navigate to="/login" />;
  }

  return (
    <AppShell>
      <Outlet />
    </AppShell>
  );
}

const authenticatedRoute = createRoute({
  getParentRoute: () => rootRoute,
  id: "_authenticated",
  component: AuthenticatedLayout,
});

const dashboardRoute = createRoute({
  getParentRoute: () => authenticatedRoute,
  path: "/",
  component: DashboardPage,
});

// eslint-disable-next-line react-refresh/only-export-components -- route tree colocated by design (§45)
function PlatformGuard() {
  const { hasRole } = useSession();
  if (!PLATFORM_NAV_ROLES.some((r) => hasRole(r))) {
    return <Navigate to="/" />;
  }
  return <PlatformPage />;
}

const platformRoute = createRoute({
  getParentRoute: () => authenticatedRoute,
  path: "/platform",
  component: PlatformGuard,
});

const routeTree = rootRoute.addChildren([
  loginRoute,
  authenticatedRoute.addChildren([dashboardRoute, platformRoute]),
]);

export const router = createRouter({ routeTree });

declare module "@tanstack/react-router" {
  interface Register {
    router: typeof router;
  }
}
