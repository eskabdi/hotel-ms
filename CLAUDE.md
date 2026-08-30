# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Engida (እንግዳ) Cloud HMS — multi-tenant Hotel Management SaaS for Ethiopian hotels. Full spec lives in `docs/engida-hms-master-blueprint-v1.md` (1300+ lines, numbered §1–50 with locked decisions D-01…D-23 at the top) — **read the relevant section before implementing any feature module, RLS policy, or dialog**; this file only summarizes what's needed to navigate the repo.

The repo is in early foundation stage: `apps/web` has the app shell, auth/session plumbing, and design tokens wired up and building clean; `supabase/migrations/0001-0008` create the identity domain (tenants/properties/users_profile/invitations/roles/permissions/role_permissions/user_roles), RLS enabled+forced on all of them, the seeded permission registry + system role templates, and the custom-access-token Auth Hook. No feature-module tables (booking/money/ops) or RPCs exist yet, and no Edge Functions. `apps/web/src/main.tsx` renders `RouterProvider` directly (no `App.tsx` — routes live in `src/app/router.tsx`).

## Commands

Monorepo uses pnpm workspaces (`apps/*`, `packages/*`).

```
pnpm dev          # runs web app only (pnpm --filter web dev), Vite on :5173
pnpm build        # pnpm -r build (all packages)
pnpm lint         # pnpm -r lint
pnpm typecheck    # pnpm -r typecheck
pnpm db:push      # supabase db push
pnpm db:reset     # supabase db reset
```

Per-package (run from `apps/web`): `pnpm lint` = `eslint . --max-warnings 0`; `pnpm typecheck` = `tsc -b --noEmit`; `pnpm build` = `tsc -b && vite build`. No test runner is configured yet in `apps/web/package.json` even though §46 specifies vitest + Playwright — check before assuming a test command exists.

`packages/shared-types` has its own `typecheck` script only (no build/lint yet).

Local dev needs `apps/web/.env` (copy from root `.env.example`) with `VITE_SUPABASE_URL` and `VITE_SUPABASE_ANON_KEY` pointed at the dev Supabase project (ref `hcwcxsijcozoqlrrisjf`). `apps/web/src/lib/supabase.ts` throws at import time if either is missing.

## Architecture

### Non-negotiable rules from the blueprint (D-01…D-23)

These are locked decisions, not suggestions — follow them for any new code:

- **Server trust (D-23):** the client never decides authorization. Permission checks, money math, and state transitions happen server-side (Postgres RPC / Edge Functions). UI-side permission checks (via `permissions.ts`) are cosmetic only — always re-checked by `app.has_perm()` in RLS/RPC.
- **Multi-tenancy (D-06):** shared schema, `tenant_id` (+ `property_id` where scoped) on every business row, RLS enabled **and forced** on all tables, no exceptions. Both ids are set by `before insert` triggers from JWT claims — never trust a client-supplied tenant/property id.
- **State transitions are Postgres RPC functions** (`security definer`), never multi-table writes from the client — this is what makes folio + room status + audit log atomic and RLS-unbypassable. Edge Functions exist only for external I/O (payment webhooks, email/SMS, PDF, iCal, exports, cron) and call the same RPCs.
- **Business date, not wall clock (D-15):** every operational query filters by `properties.business_date`, advanced only by Night Audit.
- **Currency (D-09):** ETB only, `numeric(14,2)`, no `$` in UI. FX display is opt-in behind flag `billing.fx_reference_display`.
- **Calendars (D-10):** Gregorian is the operational calendar; Ethiopian Calendar is a display-only layer (`packages/shared-types/src/ethiopic.ts` is currently a stub — real conversion is a dedicated future increment with 200 golden test vectors per §50).
- **Naming (D-08):** camelCase in TypeScript, snake_case in SQL.
- **Soft delete (D-17):** `deleted_at` for business entities; hard delete only via platform purge jobs.
- **No `dangerouslySetInnerHTML` anywhere (D-22).**

### Permissions and feature flags are code, not docs

`packages/shared-types/src/permissions.ts` is the single source of truth for the permission registry (mirrors blueprint §6.2) and must stay in sync with the seed migration `supabase/migrations/0007_seed_permissions_roles.sql` — if you add/remove a permission, update both. `flags.ts` is the feature-flag registry stub (§29 has the full ~40-key table; only add keys as their feature module actually lands). Both packages are meant to be consumed by RPC seeds, UI gating, and generated docs — don't duplicate the permission list elsewhere.

### RLS pattern

Every business table gets `app.tenant_id()`, `app.property_ids()`, `app.has_perm(key)` helper-backed policies (schema `app`, see `supabase/migrations/0002_app_schema_helpers.sql` + `0006_identity_rls.sql`), `enable row level security` + `force row level security`, and separate read/write policies keyed to the matching permission from `permissions.ts`. Money tables (`folio_lines`, `payments`, `invoices` — not yet created) will block direct `insert/update/delete` from `authenticated` entirely once they land — writes only through `security definer` RPCs. See blueprint §7 for the exact helper SQL and policy pattern, and `0005_identity_tables.sql`/`0006_identity_rls.sql` for a worked example (including the not-fully-specified-in-the-blueprint judgment call that `roles.tenant_id` is nullable — null rows are shared system-role templates, documented at the top of `0005_identity_tables.sql`).

pgTAP coverage lives in `supabase/tests/rls_coverage.sql` (run via `supabase test db`, requires `supabase start` / Docker running locally first).

### Intended repo layout (target state per §45)

```
apps/web/src/app/                # TanStack Router routes (mirror §35 nav map)
apps/web/src/features/<module>/  # api/ (query+mutation hooks) · components/ · dialogs/ (Dxxx files) · schemas
apps/web/src/components/ui/      # shadcn/ui generated, unmodified
apps/web/src/components/engida/  # wrappers: <Money/>, <StayDate/>, <StatusPill/>
apps/web/src/lib/                # supabase client, error mapper, i18n, idempotency, realtime bus
packages/shared-types/           # zod schemas, generated supabase types, ethiopic.ts, permissions.ts, flags.ts
supabase/migrations/             # 0001_extensions.sql ... forward-only, NNNN_<scope>_<desc>.sql
supabase/functions/<name>/       # Edge Functions (Deno), external I/O only
supabase/seed/, supabase/tests/  # seed.sql + demo data; pgTAP suite
```

`src/features/` is currently empty — no feature modules have landed. Rule: features never import each other's internals; share via `packages/shared-types` or `src/lib`. Dialogs live beside their feature and register in a `dialogRegistry` (id → lazy component) so the §37 dialog catalog IDs (D-001…D-082) are literal code artifacts, not just doc references.

### Session and auth flow

`SessionProvider` (`src/lib/session-provider.tsx`) is the single source of session truth — wraps `supabase.auth.getSession()` / `onAuthStateChange()`, decodes custom JWT claims client-side via `jwt-claims.ts` (UI-only decode, no signature verification — that happens server-side on every RPC/RLS check). Claims shape (`tenant_id`, `property_ids`, `roles`, `plan`, `tenant_status`, optional `imp` during impersonation) comes from a `custom_access_token` Postgres Auth Hook described in §5.4. Router guards and permission checks must read from `useSession()`, never from localStorage directly.

### Nav / feature-flag pattern

`src/app/nav-config.ts` defines `NAV_ITEMS` with an `enabled` boolean per item — items for modules not yet built stay `enabled: false` and render as disabled "coming soon" placeholders in `AppShell` rather than being omitted, so the full nav map from §35 is visible from day one.

### i18n

English + Amharic via i18next/react-i18next, resource files at `src/locales/{en,am}/common.json`, flat dot-keyed strings (e.g. `nav.dashboard`, `auth.login.title`). Default language is `en` (per-user locale preference from `users_profile.locale` is a documented follow-up, not yet wired).

### Design tokens

`tailwind.config.ts` intentionally deviates from the blueprint's own §34 palette — colors are swapped for the palette in `docs/Z_Shop_UX_Design_Color_Palette.md` per a separate plan decision. Status colors (`status.hold`, `status.dirty`, etc.) map to PMS domain states (reservation/room/HK status) — check this token map before hardcoding any status color.
