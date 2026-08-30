# ENGIDA CLOUD HMS — Master Blueprint & Detailed Specification

**Product:** Engida (እንግዳ, "guest") Cloud HMS — Multi‑tenant Hotel Management SaaS
**Version:** 1.0 (Build‑ready specification) · **Date:** 2026‑07‑21 · **Author:** Esk / Engineering
**Status:** Approved for implementation · **Doc scope:** Specification → deployable production system

---

## 0. Decisions Locked for This Blueprint

Every ambiguity has been resolved into an explicit decision below. Anything that legally *cannot* be decided at spec time (external rates, third‑party API contracts) is not "assumed" — it is captured in **§49 Runtime Confirmations** as a mandatory pre‑go‑live verification with a fallback behavior.

| # | Decision | Value | Rationale |
|---|---|---|---|
| D‑01 | Frontend | React 18 + TypeScript (strict), Vite | Team standard |
| D‑02 | UI kit | shadcn/ui + Tailwind CSS | Team standard |
| D‑03 | Data layer | TanStack Query v5 + TanStack Router | Team standard |
| D‑04 | Forms/validation | React Hook Form + Zod (shared schemas) | Team standard |
| D‑05 | Backend | Supabase: Postgres 15, Auth, Storage, Realtime, Edge Functions (Deno) | Team standard |
| D‑06 | Multi‑tenancy | Shared schema, `tenant_id` on every row, RLS enforced on **all** tables — no exceptions | Team canonical rule |
| D‑07 | Auth | Native Supabase Auth only (`signInWithPassword`, `onAuthStateChange`); no third‑party auth wrapper | Team canonical rule |
| D‑08 | Naming | camelCase in TypeScript, snake_case in SQL | Team canonical rule |
| D‑09 | Currency | ETB is the sole functional/ledger currency. All amounts stored as `numeric(14,2)` ETB. No `$` anywhere in UI. Optional read‑only FX reference display behind flag `billing.fx_reference_display` (default OFF) | Team canonical rule; NBE compliance verified in §49 |
| D‑10 | Calendars | Gregorian is the system/operational calendar (interop with OTAs, business_date math). Ethiopian Calendar (EC) is a first‑class display layer: dual date display + EC report grouping, toggleable | Local market requirement |
| D‑11 | Languages | English + Amharic (am/en) via i18n resource files; per‑user language preference | Local market requirement |
| D‑12 | Taxes (defaults) | VAT 15% exclusive, Service Charge 10% ON, Tourism/City levy 0% until confirmed (§49) | Configurable per property |
| D‑13 | Payments | Cash, Bank transfer (manual reconcile), Chapa (cards/wallets), Telebirr. Stripe adapter stubbed but disabled | Ethiopian market |
| D‑14 | SaaS billing | Manual invoice + bank‑transfer proof approval (P1) and Chapa recurring (P2). Plans priced in ETB | Ethiopian B2B reality |
| D‑15 | Business date | Explicit per‑property `business_date` advanced only by Night Audit — never derived from wall clock | PMS correctness |
| D‑16 | Double‑booking guard | Postgres GiST exclusion constraint on room assignments (DB‑level, not app‑level) | Correctness under concurrency |
| D‑17 | Deletes | Soft delete (`deleted_at`) for business entities; hard delete only via platform purge jobs | Audit & recovery |
| D‑18 | Notifications | Email via Resend; SMS via pluggable Ethiopian gateway adapter (AfroMessage/GeezSMS — provider chosen per tenant); in‑app via Realtime | Local delivery |
| D‑19 | Offline | v1 is online‑first with resilient caching (persisted TanStack Query cache of today's operational lists). Full offline PMS is P3 (§48) | Honest scope |
| D‑20 | Hosting | Frontend: Lovable → export → Vercel (prod). Backend: Supabase Cloud (one project per environment) | Team workflow |
| D‑21 | Secrets | Never committed. `.env*` gitignored from commit #1; secrets in Vercel/Supabase/GitHub secret stores | Prior audit finding |
| D‑22 | HTML injection | No `dangerouslySetInnerHTML` anywhere; rich text rendered via sanitized renderer (DOMPurify) if ever needed | Prior audit finding |
| D‑23 | Server trust | JWT verification, permission checks, money math, and state transitions happen server‑side (Postgres RPC / Edge Functions). Client never decides authorization | Prior audit finding |

---

## Table of Contents

**Part A — Product & Architecture**
1. Product vision, personas & plans · 2. System architecture · 3. Multi‑tenancy model · 4. Environments

**Part B — Identity & Access**
5. Authentication · 6. Authorization, roles & permission registry · 7. RLS strategy · 8. User & session lifecycle

**Part C — Data Model**
9. Conventions & ERD · 10. Table catalog (complete) · 11. Reference DDL & integrity constraints · 12. Storage buckets

**Part D — Feature Modules (workflows, states, transitions, actors, triggers)**
13. Reservations & availability · 14. Front desk operations · 15. Rooms, room types & rate engine · 16. Housekeeping · 17. Maintenance & work orders · 18. Folio, billing & invoicing · 19. Payments & refunds · 20. Night audit · 21. POS (F&B) · 22. Guest CRM · 23. Groups & allotments · 24. Channel / OTA connectivity · 25. Reports & analytics · 26. Notifications & messaging

**Part E — Operations & Platform Administration**
27. Super‑admin console · 28. SaaS subscription lifecycle & dunning · 29. Feature flags & configuration registry (complete) · 30. Monitoring & observability · 31. Logging & audit trail · 32. Backup & restore · 33. Data lifecycle & retention

**Part F — UI Specification**
34. Design system & global UI standards · 35. Application shell & navigation map · 36. Dialog framework standards · 37. **Dialog catalog — every modal, confirmation & wizard (D‑001…D‑082)**

**Part G — Cross‑cutting Concerns**
38. Error‑handling framework · 39. Validation standards · 40. i18n, Amharic & Ethiopian calendar · 41. Ethiopia compliance (VAT, invoicing, payments) · 42. Performance & resilience budgets · 43. Security requirements (OWASP mapping) · 44. Accessibility

**Part H — Delivery**
45. Repository structure · 46. CI/CD & migration workflow · 47. Deployment configurations · 48. Phased roadmap & estimates · 49. Go‑live checklist & runtime confirmations · 50. Acceptance criteria (per module) · Appendix A: Glossary · Appendix B: Edge Function & cron registry · Appendix C: Seed/demo data spec

---

# PART A — PRODUCT & ARCHITECTURE

## 1. Product Vision, Personas & Plans

### 1.1 Problem statement
Small and mid‑size Ethiopian hotels (10–150 rooms) run on paper registers, Excel, or aging desktop PMS software. The result: double bookings, revenue leakage between front desk and accounts, no night‑audit discipline, no VAT‑compliant invoicing, and zero visibility for owners who are often off‑site. International cloud PMS products fail locally on price (USD billing), payments (no Chapa/Telebirr), language (no Amharic), and calendar conventions.

### 1.2 Vision
A cloud PMS that a receptionist in Harar can learn in one shift and an owner in Addis can trust from a phone: reservations → front desk → housekeeping → billing → night audit → owner dashboard, fully in ETB, dual GC/EC dates, Amharic UI, and local payment rails — sold and billed like an Ethiopian B2B product.

### 1.3 Goals (measurable)
| Goal | Target | Measured by |
|---|---|---|
| G1 Zero double bookings | 0 room/date collisions in production | DB exclusion‑constraint violations = handled; collision incidents = 0 |
| G2 Front‑desk speed | Walk‑in check‑in ≤ 90 s; reservation check‑in ≤ 45 s | UI timing telemetry p75 |
| G3 Audit discipline | ≥ 95% of tenant nights closed via Night Audit within 6 h of 00:00 | `night_audit_runs` completion times |
| G4 Billing integrity | 100% of revenue postings tied to a folio; invoice sequence gap‑free per property | Reconciliation report |
| G5 Adoption | 10 paying properties in 6 months; churn < 3%/mo | Super‑admin MRR dashboard |

### 1.4 Non‑goals (v1)
Full offline mode (P3); native mobile apps (responsive web + PWA only); global distribution/GDS; multi‑currency ledger; hotel loyalty points engine (flagged P2 design hooks only); restaurant inventory/recipe costing (POS sells items, does not deplete stock in v1); payroll/HR (owner already has PayWise — integration hook only).

### 1.5 Personas & roles (summary — full RBAC in §6)
| Persona | Role code | Primary jobs |
|---|---|---|
| Platform operator (you) | `platform_admin`, `platform_support` | Tenants, plans, billing, impersonation, health |
| Hotel owner | `owner` | Everything in tenant; finances; user management |
| General manager | `manager` | Ops oversight, overrides, rates, reports |
| Front desk / receptionist | `front_desk` | Reservations, check‑in/out, folios, payments |
| Night auditor | `night_auditor` | Front desk perms + run night audit |
| Housekeeping supervisor | `hk_supervisor` | HK board, assignments, inspections, OOO requests |
| Housekeeper | `housekeeper` | Own task list, status updates, lost & found |
| Maintenance tech | `maintenance` | Work orders assigned to them |
| Accountant / cashier | `accountant` | Invoices, payments, refunds, shift close, exports |
| POS staff | `pos_staff` | Tickets, room posting |
| POS supervisor | `pos_supervisor` | POS staff + voids, day close |
| Guest (portal, P2) | `guest` | View booking, folio, pay online |

### 1.6 Subscription plans (feature matrix — enforced by flags §29)
| Capability | Starter | Growth | Pro |
|---|---|---|---|
| Properties | 1 | 1 | up to 5 |
| Rooms (per property) | ≤ 30 | ≤ 80 | ≤ 300 |
| Users | 5 | 15 | 50 |
| Core PMS (res, FD, HK, folio, audit) | ✔ | ✔ | ✔ |
| Maintenance module | ✔ | ✔ | ✔ |
| POS outlets | — | 1 | 5 |
| Groups & allotments | — | ✔ | ✔ |
| Channel iCal sync | — | ✔ | ✔ |
| Channel‑manager API adapter | — | — | ✔ |
| Guest portal & online payments | — | ✔ | ✔ |
| Advanced reports + scheduled email | — | ✔ | ✔ |
| API access / webhooks out | — | — | ✔ |
| List price (placeholder, config `plan.price_etb`) | 2,500 ETB/mo | 5,500 ETB/mo | 12,000 ETB/mo |

Prices are configuration, not code (§29). Annual = 10× monthly (2 months free), stored per plan.

---

## 2. System Architecture

### 2.1 Component diagram
```
                        ┌────────────────────────────────────────────────┐
                        │                    CLIENTS                     │
                        │  Staff Web App (React SPA)   Guest Portal (P2) │
                        │  Super‑Admin Console (same SPA, /platform)     │
                        └───────────────┬────────────────────────────────┘
                                        │ HTTPS (supabase-js v2)
        ┌───────────────────────────────┼───────────────────────────────────┐
        │                        SUPABASE PROJECT (per env)                 │
        │                                                                   │
        │  ┌──────────┐  ┌───────────────────────────────┐  ┌────────────┐  │
        │  │  Auth    │  │        Postgres 15            │  │  Storage   │  │
        │  │ (GoTrue) │  │  • app schema (tables)        │  │  buckets   │  │
        │  │ + custom │  │  • RLS on every table         │  │  (RLS)     │  │
        │  │  claims  │  │  • RPC fns = state machines   │  └────────────┘  │
        │  │  hook    │  │  • pg_cron scheduled jobs     │  ┌────────────┐  │
        │  └──────────┘  │  • triggers → audit_log       │  │  Realtime  │  │
        │                └───────────────────────────────┘  │ (boards)   │  │
        │  ┌─────────────────────────────────────────────┐  └────────────┘  │
        │  │ Edge Functions (Deno)  — external I/O only  │                  │
        │  │ chapa-webhook · telebirr-webhook · notify   │                  │
        │  │ invoice-pdf · ical-sync · tenant-export     │                  │
        │  │ backup-export · saas-dunning (cron)         │                  │
        │  └─────────────────────────────────────────────┘                  │
        └───────────────┬───────────────────────┬───────────────────────────┘
                        │                       │
              ┌─────────┴────────┐   ┌──────────┴─────────────────────────┐
              │ Resend (email)   │   │ Chapa · Telebirr · SMS gateway ·   │
              │ Sentry (errors)  │   │ OTA iCal endpoints                 │
              └──────────────────┘   └────────────────────────────────────┘
```

### 2.2 Architectural rules
1. **State transitions are Postgres RPC functions** (`security definer`, internally re‑checking permissions via §7 helpers). The client calls `rpc('check_in', …)`; it never runs multi‑table writes itself. This guarantees atomicity (folio open + room status + audit log in one transaction) and makes RLS + business rules unbypassable.
2. **Edge Functions exist only for external I/O**: payment webhooks, email/SMS, PDF rendering, iCal fetch, exports, and scheduled SaaS jobs. They use the service‑role key, verify their own auth (webhook signatures / platform JWT), and call the same RPCs.
3. **Realtime** channels are scoped `property:{property_id}:{board}` (frontdesk, housekeeping, pos). Postgres changes on `rooms`, `reservations`, `hk_tasks`, `pos_tickets` are broadcast; clients invalidate TanStack Query keys — Realtime is a cache‑invalidation signal, never the source of truth.
4. **Idempotency**: every money‑moving RPC and webhook takes an `idempotency_key` (unique index). Replays return the original result.
5. **The wall clock is not the business date.** All operational queries filter by `properties.business_date` (D‑15).

### 2.3 Load & scale envelope (design targets)
150 rooms × 5 properties × 200 tenants ≈ 150k room‑nights/mo; peak write ~20 req/s (check‑out hour); night audit batch ≤ 60 s per property at 300 rooms. Postgres on Supabase Pro (4 GB) suffices to ~500 tenants; scaling levers: read replicas for reports (P3), monthly partitioning of `folio_lines`, `audit_log`, `pos_ticket_lines` from day one so partition pruning is free later.

---

## 3. Multi‑Tenancy Model

```
platform
 └── tenants (hotel company)  ── subscription, plan, status
      └── properties (hotel)  ── business_date, tax config, invoice sequence
           ├── users (memberships: user × tenant × property[] × roles[])
           ├── rooms / room_types / rate_plans …
           └── all operational data (tenant_id + property_id on every row)
```

Rules: (a) every business table carries `tenant_id uuid not null` and, where property‑scoped, `property_id uuid not null`; (b) both are set by `before insert` triggers from JWT claims — the client cannot spoof them; (c) cross‑tenant reads are impossible by RLS (§7); cross‑property reads within a tenant are limited by the user's `property_ids` claim; (d) platform staff never query with service role from a browser — impersonation (§27.4) mints a scoped, time‑boxed tenant JWT instead.

Tenant lifecycle states: `trial → active → past_due → suspended → cancelled → purge_scheduled → purged` (full machine in §28).

---

## 4. Environments

| Env | Supabase project | Frontend | Data | Purpose |
|---|---|---|---|---|
| `dev` | engida-dev | localhost / Lovable preview | Seed + synthetic (App. C) | Daily development |
| `staging` | engida-staging | staging.engida.et (Vercel preview→promote) | Anonymized copy or seed | UAT, migration rehearsal, restore drills |
| `prod` | engida-prod | app.engida.et | Live | Production |

Environment parity is enforced by migrations‑as‑code (§46). Config divergence allowed only for: secrets, provider keys, `pg_cron` schedules (staging runs audits hourly for testing), Sentry DSN, and rate limits.

---

# PART B — IDENTITY & ACCESS

## 5. Authentication

### 5.1 Methods
| Method | Who | Notes |
|---|---|---|
| Email + password | All staff | Primary. Supabase native `signInWithPassword`. |
| Email OTP (magic code) | Fallback / guest portal (P2) | 6‑digit, 10‑min expiry. |
| TOTP MFA | Required for `owner`, `manager`, `accountant`, `platform_*` when `security.mfa_required_roles` includes the role (default: platform roles + owner) | Supabase MFA API; recovery codes generated at enrollment. |
| Phone/SMS OTP | P2 (guest portal) | Behind flag; depends on SMS gateway reliability. |

### 5.2 Password & account policy
Minimum 10 chars, at least 1 letter + 1 number (Zod schema shared client/server); leaked‑password protection ON (Supabase HIBP integration); 5 failed logins → 15‑min lockout (GoTrue rate limits + UI messaging); password reset link expiry 60 min, single‑use; email change requires re‑auth + confirmation to both addresses.

### 5.3 Sessions & tokens
Access token TTL 60 min; refresh token rotation ON, reuse detection ON. Idle timeout is app‑enforced: after `security.session_idle_minutes` (default 30; POS terminals 240 via device setting) of no interaction, show **D‑003 Session Expiry** with 120‑s countdown; on expiry call `supabase.auth.signOut()` and route to `/login?reason=idle`. `onAuthStateChange` is the single source of session truth; the router guard reads a `SessionProvider`, never localStorage directly.

### 5.4 Custom JWT claims (Auth Hook)
A `custom_access_token` hook injects:
```json
{
  "tenant_id": "…uuid…",
  "property_ids": ["…"],
  "roles": ["front_desk","night_auditor"],
  "plan": "growth",
  "tenant_status": "active",
  "imp": { "by": "…platform user id…", "exp": 1750000000 }   // only during impersonation
}
```
Claims are recomputed on refresh; role changes therefore take effect ≤ 60 min or immediately after forced refresh (`auth.refreshSession()` is called by the client when it receives the `roles_changed` Realtime event for its own user id). If `tenant_status` ∈ {`suspended`,`past_due`+grace exceeded}, the app mounts read‑only mode (§28.3).

### 5.5 Login flow (states)
`anonymous → credentials_submitted → (mfa_required → mfa_challenged) → authenticated → workspace_selected`. If the user belongs to >1 property, a property picker (D‑008) follows login; selection is stored per device and switchable from the top bar. If the user has 0 active memberships → screen "No access — contact your administrator" (no tenant data fetched).

## 6. Authorization — Roles & Permission Registry

### 6.1 Model
`roles` are named bundles of `permissions` (many‑to‑many via `role_permissions`); users get roles per tenant with optional property scoping (`user_roles.property_id null` = all properties). Permissions are the atomic unit checked everywhere: in RLS write policies, inside RPCs, and in the UI (to hide/disable controls — UI checks are cosmetic only; D‑23). Custom roles: Pro plan may clone a system role and edit its permission set (`roles.is_system=false`); system roles are immutable.

### 6.2 Permission registry (complete — the authorization contract)
| Permission key | Description | Default roles (beyond owner, who has all) |
|---|---|---|
| `reservation.read` | View reservations & calendar | manager, front_desk, night_auditor, hk_supervisor (read‑only), accountant |
| `reservation.create` | Create bookings/holds/walk‑ins | manager, front_desk, night_auditor |
| `reservation.update` | Edit dates, guests, notes | manager, front_desk, night_auditor |
| `reservation.cancel` | Cancel within policy | manager, front_desk, night_auditor |
| `reservation.cancel.override` | Cancel outside policy / waive fee | manager |
| `reservation.rate_override` | Manual rate at booking (reason required) | manager; front_desk if flag `res.fd_rate_override` |
| `reservation.noshow` | Mark no‑show manually | manager, night_auditor |
| `reservation.reinstate` | Reinstate cancelled/no‑show/checked‑out | manager |
| `frontdesk.checkin` / `frontdesk.checkout` | Perform check‑in / check‑out | manager, front_desk, night_auditor |
| `frontdesk.room_move` | Move in‑house guest | manager, front_desk, night_auditor |
| `frontdesk.checkout_with_balance` | Check out with nonzero balance | manager (limit `ops.max_checkout_balance_etb`) |
| `room.read` / `room.manage` | View rooms / edit rooms & types | read: all staff; manage: manager |
| `room.ooo` | Set Out‑of‑Order / Out‑of‑Service | manager, hk_supervisor, maintenance (request→approve if flag) |
| `rate.read` / `rate.manage` | View rates / edit plans, seasons, restrictions | read: manager, front_desk, accountant; manage: manager |
| `hk.read` / `hk.update_status` | See HK board / change room clean status | read: FD+HK+mgr; update: housekeeper (own‑assigned per flag `hk.restrict_to_assigned`), hk_supervisor, front_desk (to *dirty* only) |
| `hk.assign` / `hk.inspect` | Assign tasks / pass‑fail inspection | hk_supervisor, manager |
| `mx.read` / `mx.create` | View / raise work orders | all staff may create; read: maintenance, hk_supervisor, manager |
| `mx.assign` / `mx.close` | Assign / verify‑close WOs | manager, hk_supervisor (assign), manager (close) |
| `folio.read` / `folio.post` | View folios / post charges | read: FD, accountant, mgr; post: FD, night_auditor, pos_* (room‑post only), accountant |
| `folio.transfer` / `folio.split` | Move charges / split folios | FD, accountant, manager |
| `folio.void_sameday` | Void a same‑business‑date line (reason) | FD, accountant, manager |
| `folio.adjust` | Post‑audit correction/allowance (reason) | accountant, manager |
| `folio.reopen` | Reopen a settled/closed folio | manager |
| `payment.take` | Record cash/transfer, initiate Chapa/Telebirr | FD, night_auditor, accountant, pos_supervisor |
| `payment.refund` | Refund (≤ `pay.refund_approval_threshold_etb` self‑serve; above → approval task to manager) | accountant, manager |
| `invoice.issue` / `invoice.credit_note` | Issue fiscal invoice / credit note | FD (issue), accountant, manager |
| `cashier.shift` | Open/close own cashier shift | FD, accountant, pos_supervisor, night_auditor |
| `cashier.shift.review` | Review/approve over‑short | accountant, manager |
| `audit.run` | Execute night audit | night_auditor, manager |
| `pos.sell` / `pos.void` / `pos.dayclose` | Ticket ops / void lines / close day | sell: pos_staff+; void & dayclose: pos_supervisor, manager |
| `guest.read` / `guest.manage` / `guest.merge` | Profiles / edit / merge duplicates | read: FD+; manage: FD, mgr; merge: manager |
| `guest.dnr` | Set/lift Do‑Not‑Rent flags | manager |
| `guest.export` / `guest.anonymize` | Data export / anonymization | manager, owner |
| `group.manage` | Blocks, allotments, rooming lists | manager, front_desk (if flag `group.fd_manage`) |
| `channel.manage` | iCal links, channel mapping, sync queue | manager |
| `report.operational` / `report.financial` | Ops reports / revenue & cashier reports | ops: mgr, FD, HK sup; financial: accountant, manager, owner |
| `settings.property` / `settings.tax` / `settings.billing_providers` | Property config / tax rates / payment keys | manager (property), owner (tax, providers) |
| `user.manage` / `role.manage` | Invite/deactivate users / edit custom roles | owner, manager (user.manage only) |
| `audit_log.read` | View audit trail | owner, manager, accountant (financial entries) |
| `notification.templates` | Edit message templates | manager |
| `platform.*` | Tenant CRUD, plans, impersonate, announcements, backups, flags | platform_admin (all); platform_support (read + impersonate) |

Every permission above maps 1:1 to: an RLS write policy or RPC guard, at least one UI affordance, and an audit‑log action name. **§50 acceptance tests iterate this table.**

## 7. RLS Strategy

### 7.1 Helper functions (schema `app`)
```sql
create schema if not exists app;

create or replace function app.tenant_id() returns uuid
language sql stable as $$
  select nullif(current_setting('request.jwt.claims', true)::jsonb->>'tenant_id','')::uuid
$$;

create or replace function app.property_ids() returns uuid[]
language sql stable as $$
  select coalesce(
    (select array_agg(value::uuid)
       from jsonb_array_elements_text(
         current_setting('request.jwt.claims', true)::jsonb->'property_ids')),
    '{}')
$$;

create or replace function app.has_perm(p text) returns boolean
language sql stable security definer set search_path = public, app as $$
  select exists (
    select 1
    from user_roles ur
    join role_permissions rp on rp.role_id = ur.role_id
    join permissions pm on pm.id = rp.permission_id
    where ur.user_id = auth.uid()
      and ur.tenant_id = app.tenant_id()
      and pm.key = p
      and (ur.property_id is null or ur.property_id = any (app.property_ids()))
  )
$$;
```

### 7.2 Policy pattern (applied to every business table)
```sql
alter table reservations enable row level security;   -- and FORCE for owners of the table
alter table reservations force row level security;

create policy tenant_read on reservations for select
  using (tenant_id = app.tenant_id()
     and property_id = any (app.property_ids())
     and app.has_perm('reservation.read'));

create policy tenant_write on reservations for insert
  with check (tenant_id = app.tenant_id()
     and property_id = any (app.property_ids())
     and app.has_perm('reservation.create'));
-- UPDATE/DELETE analogous; most state changes are RPC‑only:
-- direct UPDATE limited to safe columns via column‑level GRANTs.
```
Additional rules: money tables (`folio_lines`, `payments`, `invoices`) allow **no** direct `insert/update/delete` from `authenticated` — all writes go through `security definer` RPCs that re‑check `app.has_perm(…)` and write audit entries; `service_role` is used only inside Edge Functions; anonymous role has zero grants; Storage policies mirror the same claims (§12); pgTAP tests in CI assert "RLS enabled + forced" on 100% of tables (§46.4).

## 8. User & Session Lifecycle

### 8.1 Invitation state machine
| State | Entered by | Exits |
|---|---|---|
| `invited` | `user.manage` actor via D‑060 (creates `invitations` row + Supabase invite email, 7‑day expiry) | → `accepted` (link + password set) · → `expired` (cron `invitation-expiry`) · → `revoked` (admin) |
| `accepted` | Invitee completes D‑061 Accept‑Invite | Membership rows created; welcome notification |
| `expired`/`revoked` | System / admin | Re‑invite allowed (new token; old link shows friendly error) |

### 8.2 Member states
`active ⇄ suspended` (admin toggle; suspended = sign‑in allowed but zero memberships resolve → "No access" screen; sessions killed via `roles_changed` broadcast) → `deactivated` (soft; historical records keep `created_by`; email freed after 30 days for re‑invite). A user may belong to multiple tenants (platform supports it; UI shows tenant switcher only when >1).

### 8.3 Session edge cases
Token refresh failure offline → retry with backoff, then D‑003 with "reconnect" state; clock skew > 120 s → banner "Device clock incorrect — some actions may fail"; concurrent role downgrade mid‑action → RPC re‑check throws `AUTHZ_DENIED` → D‑004 Permission Denied; impersonation sessions display a persistent red banner and hard‑expire at `imp.exp` (≤ 60 min) with an unclosable 60‑s warning dialog before forced sign‑out.

---

# PART C — DATA MODEL

## 9. Conventions & ERD Overview

snake_case; `uuid` PKs (`gen_random_uuid()`); `tenant_id` (+ `property_id` where scoped) on every business row, set by trigger from JWT; `created_at/updated_at timestamptz` with `moddatetime` trigger; soft delete `deleted_at`; money `numeric(14,2)` ETB; dates that mean "hotel night" are `date` (business‑date semantics), instants are `timestamptz`; all FKs indexed; enums as Postgres `enum` types; monthly `PARTITION BY RANGE` on `folio_lines`, `payments`, `audit_log`, `pos_ticket_lines`, `notifications_outbox`.

ERD domains: **Identity** (tenants, properties, users, memberships, roles) → **Inventory** (room_types, rooms, rate_plans, rates, restrictions, inventory_counters) → **Booking** (guests, reservations, reservation_rooms, groups) → **Money** (folios, folio_lines, payments, invoices, credit_notes, cashier_shifts) → **Ops** (hk_tasks, work_orders, night_audit_runs, pos_*) → **Platform** (subscriptions, plan_features, feature_flags, audit_log, notifications_outbox, backups).

## 10. Table Catalog (complete)

| # | Table | Purpose / key columns beyond standard (`id, tenant_id, property_id?, created_*, updated_*, deleted_at`) |
|---|---|---|
| 1 | `tenants` | name, legal_name, tin, status(enum §28), plan_id, trial_ends_at, billing_email, region/zone/woreda/kebele address block, default_locale |
| 2 | `properties` | tenant‑scoped hotel: name, code (3‑char, invoice prefix), **business_date date**, checkin_time, checkout_time, timezone default 'Africa/Addis_Ababa', address block, phone, tax config FK, invoice_seq bigint, receipt_seq |
| 3 | `users_profile` | mirrors auth.users: full_name, phone(+251…), locale(am/en), avatar_path, last_seen_at |
| 4 | `invitations` | email, roles[], property_ids[], token_hash, status, expires_at, invited_by |
| 5 | `roles` | key, name_en, name_am, is_system, cloned_from |
| 6 | `permissions` | key, description, category |
| 7 | `role_permissions` | role_id, permission_id (unique pair) |
| 8 | `user_roles` | user_id, role_id, property_id nullable, unique(user,role,property) |
| 9 | `room_types` | code, name_en/name_am, base_occupancy, max_occupancy, max_adults/children, bed_config, size_sqm, description, photos[], sort, active |
| 10 | `rooms` | room_type_id, number (unique per property), floor, features jsonb (view, smoking, accessible…), hk_status enum, occupancy_status enum, ooo boolean derived view, notes |
| 11 | `room_status_log` | room_id, from_hk, to_hk, actor, source(checkout/hk/inspection/audit), at — feeds discrepancy + HK productivity |
| 12 | `rate_plans` | code, name, parent_id (derived), derive_mode(pct/amount), derive_value, meal_plan(RO/BB/HB/FB), cancel_policy_id, is_public, currency='ETB', active |
| 13 | `cancel_policies` | name, rules jsonb: [{hours_before, fee_type(nights/pct/flat), fee_value}], noshow_fee_type/value |
| 14 | `rates` | rate_plan_id, room_type_id, date, price numeric — the resolved daily grid (materialized by rate engine §15.3) |
| 15 | `rate_seasons` | rate_plan_id, name, date ranges[], dow_mask, price per room_type jsonb — the *source* rules |
| 16 | `restrictions` | room_type_id, rate_plan_id?, date, min_los, max_los, cta, ctd, stop_sell |
| 17 | `inventory_adjustments` | room_type_id, date, overbook_allowance int, note — availability math §13.2 |
| 18 | `guests` | first/last name, phone, email, id_type(passport/national_id/kebele_id/license), id_number, nationality, dob, address block (region/zone/woreda/kebele OR country/city), company_id?, preferences jsonb, dnr_level(none/warn/block), dnr_reason, stats(stays, nights, revenue, last_stay) maintained by trigger |
| 19 | `companies` | corporate accounts: name, tin, credit_limit, payment_terms_days, contact block, ar_balance |
| 20 | `reservations` | confirmation_no (ENG‑{prop}{yy}‑{seq}), guest_id, company_id?, group_id?, status enum §13.1, source(walkin/phone/web/ota/corp), channel_ref, arrival date, departure date, adults, children, rate_plan_id, notes, hold_expires_at, cancelled_at/by/reason, noshow_fee_posted bool |
| 21 | `reservation_rooms` | reservation_id, room_type_id, room_id nullable until assign, **stay daterange generated**, price_override numeric?, override_reason, guest names jsonb — unit of inventory; see §11.2 exclusion constraint |
| 22 | `reservation_daily_rates` | reservation_room_id, date, rate, rate_source(plan/override/group) — locked at confirm; re‑rate events append with reason |
| 23 | `groups` | name, company_id?, block dates, cutoff_date, status(tentative/definite/cancelled), rate mode, master_folio_id |
| 24 | `group_allotments` | group_id, room_type_id, date, blocked, picked_up |
| 25 | `folios` | reservation_room_id? (guest folio) / group_id? (master) / company_id? (AR), folio_no, type(guest/master/ar/pos), status enum §18.1, balance cached, routing rules jsonb |
| 26 | `folio_lines` *(partitioned)* | folio_id, business_date, type(room/tax/service/fnb/misc/payment/adjustment/transfer), sign, description, qty, unit_price, amount, tax jsonb {vat, service, levy}, source(rpc name), ref (pos ticket / payment id), voided_by_line_id?, posted_by |
| 27 | `payments` *(partitioned)* | folio_id, method(cash/transfer/chapa/telebirr), direction(in/refund), amount, status enum §19.2, provider_ref, idempotency_key unique, received_by, shift_id, verified_by (transfers), reason (refunds) |
| 28 | `invoices` | invoice_no (gap‑free per property: `{code}-{yyyy}-{000000}` from `invoice_seq` inside issuing txn), folio_id, guest/company snapshot jsonb, lines snapshot jsonb, totals {subtotal, service, vat, levy, grand}, status(issued/void‑by‑credit‑note), issued_at/by, pdf_path |
| 29 | `credit_notes` | invoice_id, reason, lines, totals, sequence share with invoices (`type` column) — never delete invoices |
| 30 | `cashier_shifts` | user_id, opened_at, opening_float, closed_at, counted jsonb (denominations), expected, over_short, status(open/closed/reviewed), reviewed_by |
| 31 | `hk_tasks` | room_id, type(departure/stayover/turndown/deep/custom), status(pending/in_progress/done/inspected/failed), assigned_to, credits, started/finished, inspection jsonb |
| 32 | `hk_discrepancies` | room_id, reported(occupancy per HK), expected(per PMS), type(sleeper/skipper/other), status(open/resolved), resolution |
| 33 | `lost_found` | room_id?, description, photo_path, found_by, status(stored/returned/donated), guest_id?, returned_at |
| 34 | `work_orders` | wo_no, room_id?/area, category, priority(P1..P4), sla_due_at, status enum §17.1, reported_by, assigned_to, hold_reason, parts_cost, photos[], verified_by |
| 35 | `room_blocks` | room_id, kind(OOO/OOS), daterange, reason, work_order_id?, created_by — OOO excludes from availability; OOS does not |
| 36 | `night_audit_runs` | property_id, business_date unique together, status(running/failed/complete), steps jsonb [{key,status,started,finished,error}], started_by, totals snapshot |
| 37 | `pos_outlets` | name, type(restaurant/bar/spa), tax profile, active |
| 38 | `pos_categories` / `pos_items` | menu: name_en/am, price, tax flags, active, sort |
| 39 | `pos_tickets` | outlet_id, ticket_no, table_no?, status(open/room_posted/paid/void), guest lookup ref, opened_by, closed_at, shift_id |
| 40 | `pos_ticket_lines` *(partitioned)* | ticket_id, item snapshot, qty, price, modifiers jsonb, void {by, reason, at} |
| 41 | `channels` | type(ical_in/ical_out/cm_api), room_type mapping, url/token, status, last_sync_at, error |
| 42 | `channel_sync_log` | channel_id, direction, payload hash, result, conflicts jsonb |
| 43 | `notifications_outbox` *(partitioned)* | to (email/phone/user_id), channel(email/sms/inapp), template_key, locale, vars jsonb, status(queued/sent/failed/dead), attempts, provider_ref, next_retry_at |
| 44 | `notification_templates` | template_key, channel, locale, subject, body (variables `{{guest_name}}` …), is_system, updated_by |
| 45 | `settings` | scope(tenant/property), key, value jsonb, updated_by — the configuration registry storage (§29) |
| 46 | `feature_flags` | scope(platform/plan/tenant), key, value, note — evaluated by `app.flag(key)` with precedence tenant > plan > platform |
| 47 | `plans` / `plan_features` | plan pricing + limits matrix (§1.6) |
| 48 | `subscriptions` | tenant_id, plan_id, period, price_etb, status, current_period_end, payment_method(manual/chapa), grace_until |
| 49 | `saas_invoices` / `saas_payments` | platform‑side billing incl. transfer proof uploads + approval |
| 50 | `audit_log` *(partitioned, insert‑only)* | actor_id, actor_roles, action (matches §6.2 keys + system events), entity, entity_id, before jsonb, after jsonb, ip, user_agent, impersonated_by?, at |
| 51 | `api_keys` (Pro) | hashed key, scopes[], last_used, revoked_at |
| 52 | `webhooks_out` (Pro) | url, secret, events[], status, failure_count |
| 53 | `backups` | kind(logical/tenant_export), path, size, checksum, status, started/finished — §32 |
| 54 | `announcements` | platform banners: audience(plan/tenant/all), severity, body, active window |
| 55 | `guest_portal_links` (P2) | reservation_id, token_hash, expires_at, scopes |

## 11. Reference DDL & Integrity Constraints

### 11.1 Enum types (authoritative)
```sql
create type reservation_status as enum
  ('hold','confirmed','checked_in','checked_out','cancelled','no_show','expired');
create type hk_status as enum
  ('vacant_dirty','vacant_clean','vacant_inspected','occupied_dirty','occupied_clean');
create type occupancy_status as enum ('vacant','occupied','blocked');
create type folio_status as enum ('open','settled','closed','reopened','disputed');
create type payment_status as enum
  ('initiated','pending','succeeded','failed','voided','refund_pending','refunded');
create type wo_status as enum
  ('reported','triaged','assigned','in_progress','on_hold','completed','verified','closed','cancelled');
create type tenant_status as enum
  ('trial','active','past_due','suspended','cancelled','purge_scheduled','purged');
```

### 11.2 Concurrency‑critical constraints
```sql
-- One physical room can never be double-assigned for overlapping nights (D‑16).
create extension if not exists btree_gist;
alter table reservation_rooms
  add column stay daterange generated always as
    (daterange(arrival, departure, '[)')) stored,
  add constraint no_double_assignment
    exclude using gist (room_id with =, stay with &&)
    where (room_id is not null
           and status in ('confirmed','checked_in'));

-- One night audit per property per business date.
alter table night_audit_runs
  add constraint one_audit_per_date unique (property_id, business_date);

-- Gap-free invoice numbers: sequence consumed inside the issue_invoice RPC txn
-- (advisory lock on property_id) so rollback never burns a number.

-- Payments idempotency.
alter table payments add constraint uq_payment_idem unique (tenant_id, idempotency_key);

-- Optimistic concurrency: all edit RPCs take expected_updated_at;
-- mismatch raises SQLSTATE 'P0409' → client shows D‑005 Record Changed.
```

### 11.3 Trigger inventory
`set_tenant_from_jwt` (before insert, all tables) · `touch_updated_at` · `audit_row_change` (after I/U/D on sensitive tables → `audit_log`) · `guest_stats_rollup` (after folio settle) · `room_status_log_writer` · `folio_balance_cache` (after folio_lines change) · `reservation_confno` (per‑property sequence) · `outbox_notify` (pg_net → notify Edge fn) — every trigger listed in migration `0004_triggers.sql` with tests.

## 12. Storage Buckets

| Bucket | Path convention | Access policy |
|---|---|---|
| `guest-ids` | `{tenant}/{guest_id}/{uuid}.jpg` | Write: `guest.manage`; Read: `guest.read`; never public; 2‑year retention then purge job (§33) |
| `invoices` | `{tenant}/{property}/{yyyy}/{invoice_no}.pdf` | Read: `folio.read`/`invoice.issue` holders + guest‑portal signed URLs (10‑min) |
| `wo-photos` | `{tenant}/wo/{wo_id}/…` | mx.* holders |
| `room-photos` | `{tenant}/rooms/…` | Public‑read via CDN (marketing), write `room.manage` |
| `backups` | `platform/{env}/{yyyy‑mm‑dd}/…` | service_role only; platform_admin via signed URL |
| `saas-proofs` | `{tenant}/billing/…` | Tenant owner write; platform read |
All buckets: RLS policies compare the first path segment to `app.tenant_id()`; max upload 10 MB (IDs/photos) with client‑side compression; MIME allow‑list per bucket.

---

# PART D — FEATURE MODULES

Every module below specifies: purpose → state machine (states, transitions, actors, triggers, guards, side effects) → key screens → RPC surface → edge cases. Dialogs referenced as D‑0xx are fully specified in §37.

## 13. Reservations & Availability

### 13.1 Reservation state machine
```
            create hold                  confirm
  (start) ──────────────► HOLD ───────────────────► CONFIRMED ──────► CHECKED_IN ─────► CHECKED_OUT
              │             │  TTL expiry               │  ▲               │                  ▲
              │             ▼                           │  │ reinstate     │ room move        │ reinstate
              │           EXPIRED                       │  │ (manager)     ▼ (loop)           │ (same biz date)
              │                                  cancel │  │            CHECKED_IN            │
              └── direct create ──► CONFIRMED           ▼  │                                  │
                                                   CANCELLED                                  │
                                                        ▲                                     │
                                        audit/manual    │                                     │
                                   CONFIRMED ──────► NO_SHOW ── reinstate (manager) ──────────┘
```

| From → To | Trigger | Actor | Guards | Side effects |
|---|---|---|---|---|
| ∅ → hold | "Hold" in D‑010 wizard | front_desk+, booking engine | availability ≥ requested (per §13.2); TTL = `res.hold_ttl_minutes` (default 60) | Soft inventory decrement; `hold_expires_at`; cron `hold-expiry` scheduled |
| hold → confirmed | Confirm button / deposit webhook | FD+, system | Deposit satisfied if `res.deposit_required` policy demands | Daily rates locked into `reservation_daily_rates`; confirmation_no issued; email/SMS `booking_confirmed` |
| hold → expired | TTL passes | cron (1‑min) | Not converted | Inventory released; audit `reservation.expired`; optional lost‑hold notification to staff |
| ∅ → confirmed | Direct create (D‑010) | FD+, channel import | Availability OR overbook allowance; else needs `reservation.rate_override`+D‑015 acknowledgment | As above |
| confirmed → cancelled | D‑012 Cancel | FD+ within policy; manager override outside | `cancel_policies` evaluated vs now → fee amount computed & displayed | Fee posted to folio (auto‑opened if none) as `cancellation_fee`; inventory released; `booking_cancelled` message; channel push |
| confirmed → no_show | Night audit step 1 (auto list) or D‑013 | night_auditor/manager | business_date ≥ arrival; not checked in | No‑show fee per policy posted; inventory released for remaining nights; stats counter |
| confirmed → checked_in | D‑030 Check‑in wizard completes | FD+ | See §14.2 guard table | Folio opened; room `occupied`; HK stayover schedule seeded; registration card generated |
| checked_in → checked_out | D‑033 Check‑out completes | FD+ | Balance rules §14.3 | Folio → settled; room → `vacant_dirty` + departure `hk_task`; invoice issued if not already; `thank_you` message (flag) |
| checked_in → checked_in | D‑032 Room Move | FD+ | Target room availability + clean rule | Re‑rate per `ops.room_move_rerate` (keep/new‑rate‑from‑move‑date); both rooms' HK tasks; audit with reason |
| cancelled/no_show/checked_out → confirmed/checked_in | D‑014 Reinstate | manager | Inventory re‑check; checked_out reinstate only same business_date | Fees optionally reversed via adjustment; audit mandatory reason |

### 13.2 Availability math (single source of truth: SQL view `v_availability`)
```
available(type, date) = physical_rooms(type, active, not deleted)
                      − OOO_blocked(type, date)                 (room_blocks kind='OOO')
                      − sold(type, date)                        (reservation_rooms status in hold*,confirmed,checked_in covering date; *holds count)
                      + overbook_allowance(type, date)          (inventory_adjustments, default 0)
```
Negative availability is displayed (red) but bookable only through the explicit overbooking acknowledgment path (D‑015, requires `reservation.rate_override`‑class permission `reservation.create` + flag `res.allow_overbooking`). Assignment‑time safety is separate: the GiST constraint (§11.2) makes *physical* double‑assignment impossible regardless of type‑level overbooking.

### 13.3 Booking sources & entry points
Walk‑in (D‑031 fast path) · phone/desk (D‑010 full wizard) · website widget (P2 guest portal, creates `hold` then Chapa deposit → confirm webhook) · OTA/iCal (creates confirmed with `source='ota'`, unassigned room, rate = channel rate or mapped plan) · corporate/group pickup (§23).

### 13.4 Reservation screens
**Tape chart / stay calendar** (rooms × 14/30 days; drag to create → opens D‑010 prefilled; drag to move → D‑032; color = status; OOO hatched; unassigned tray on top) · **Reservation list** (filters: status, date window, source, unassigned, balance>0; saved views) · **Reservation detail** (header status pill + actions, tabs: Stay, Guests, Folio, Messages, History[audit]).

### 13.5 RPC surface
`create_reservation`, `confirm_hold`, `cancel_reservation`, `mark_no_show`, `reinstate_reservation`, `assign_room`, `move_room`, `update_stay_dates` (re‑checks availability + re‑rates with diff preview data returned first via `preview=true` mode), `apply_rate_override` — each takes `idempotency_key` + `expected_updated_at`.

### 13.6 Edge cases (normative)
Same‑day arrival after midnight but before audit → arrival date = current business_date (UI banner explains); date change shrinking stay below already‑posted nights → blocked, offer early‑departure flow instead; extending stay into unavailable dates → partial availability dialog offers room move split (creates second reservation_room linked); guest requests specific room already held by hold → show hold owner + expiry, allow manager "break hold" with notification to the hold creator; child/extra‑bed pricing = rate plan add‑ons (per person delta) recalculated on occupancy edit; duplicate booking detection: same guest phone + overlapping dates → non‑blocking warning chip in wizard step 1.

## 14. Front Desk Operations

### 14.1 Dashboard (role home for FD)
Business‑date banner (red if system date ≠ business_date +1 tolerance) · KPI strip: Arrivals expected/done, Departures expected/done, In‑house, Occ% tonight, Balance due total · Queues: Arrivals (rows → D‑030), Departures (rows → D‑033), Unassigned reservations, Holds expiring < 2 h, DNR alerts today · Quick actions: Walk‑in (D‑031), New reservation (D‑010), Take payment (D‑040), Open cashier shift (D‑046).

### 14.2 Check‑in guard table (evaluated by `check_in` RPC; each failure returns a coded, actionable error the wizard maps to inline steps)
| Guard | Condition | On fail |
|---|---|---|
| G1 date | arrival = business_date, OR early check‑in allowed: business_date = arrival−1 ∧ now ≥ `ops.early_checkin_from` ∧ fee auto‑line offered | Blocked with explanation; manager may not override G1 beyond −1 day |
| G2 room assigned | reservation_room.room_id not null | Wizard step 3 forces assignment |
| G3 room clean | rooms.hk_status satisfies `ops.checkin_room_requirement` ∈ {any, clean, inspected} (default clean) | Override path: perm `hk.inspect` OR manager → confirm D‑036 with reason, logged |
| G4 room vacant | occupancy_status = vacant ∧ no OOO block covering tonight | Hard block; suggest alternatives (same type, then upgrade list) |
| G5 identity | If `guest.id_required_checkin`: id_type+number present; foreign nationals ⇒ passport | Inline capture in step 2 (camera upload to `guest-ids`) |
| G6 DNR | guest.dnr_level: warn → interstitial D‑037 acknowledge; block → manager PIN/override only | Audit `guest.dnr_bypass` |
| G7 payment | Deposit policy satisfied per rate plan (`deposit_type`: none/first_night/pct/flat) or override perm | Step 4 collects via D‑040 |
| G8 tenant status | tenant active (not read‑only) | Global read‑only banner; action disabled |

### 14.3 Check‑out rules
Preconditions surfaced in D‑033: all POS open tickets for the room must be room‑posted or closed (blocking list with deep links); balance must be 0 unless actor holds `frontdesk.checkout_with_balance` ∧ |balance| ≤ `ops.max_checkout_balance_etb` (then folio → `settled` with AR transfer line to company folio, or `disputed` flag). Late checkout: if now > `properties.checkout_time` + grace `ops.late_checkout_grace_min`, fee line auto‑proposed (`ops.late_checkout_fee` flat or % of night, editable pre‑post with perm). Early departure: departure < original → D‑034 confirm re‑rate mode (`keep_rate` / `rerate_stay` per flag) + optional early‑departure fee; remaining nights' inventory released. After success: invoice auto‑issue if `billing.auto_invoice_on_checkout` (default ON), else "Issue invoice" CTA remains on folio.

### 14.4 In‑house operations
Room move (D‑032) · Stay extension (availability + rate preview) · Guest messages/notes with "deliver on next open" flag · Wake‑up/task notes (simple `hk_tasks` type custom) · Keycard issuance is *logged only* (no lock integration v1; `key_events` in audit) · Sleep‑out / share‑with second guest added to registration.

### 14.5 Cashier shifts (money custody)
Every payment row requires an open `cashier_shift` of the acting user (guard in `take_payment`). Open: D‑046 float count. Close: D‑047 denomination count → expected computed from payments(method=cash, shift) ± paid‑outs → over/short posted to `cash_over_short` GL bucket and flagged for `cashier.shift.review`. Night audit blocks if any shift for the business_date is still open (precondition list).

## 15. Rooms, Room Types & Rate Engine

### 15.1 Room lifecycle
`active ⇄ inactive` (inactive = removed from availability from a chosen date; blocked if future assigned reservations exist → conflict list with relocate flow). Physical attributes editable anytime; room **number** change requires no future assignments or manager confirm (documents reprint warning).

### 15.2 Room type & inventory edits
Adding rooms to a type immediately raises availability (audit entry). Reducing (deactivating rooms) runs a future‑conflict scan; conflicts must be relocated (bulk relocate assistant lists affected reservation_rooms with suggested targets) before commit — no partial saves.

### 15.3 Rate engine
Sources → resolver → materialized grid:
1. **Rate plans** (BAR public baseline; derived plans compute from parent: `parent ± pct/amount`, floors at `rate.min_price_etb` per type; corporate/negotiated plans fixed).
2. **Seasons** per plan: named date ranges + day‑of‑week mask + per‑room‑type prices. Overlap resolution: most‑specific wins (explicit priority integer; editor blocks ambiguous same‑priority overlaps at save with visual diff).
3. **Resolver job** (`rate-materializer`, on save + nightly) writes `rates(rate_plan_id, room_type_id, date, price)` for horizon `rate.horizon_days` (default 365). Booking‑time lookup is a plain indexed read — no runtime rule evaluation.
4. **Restrictions** evaluated at quote time: `stop_sell` removes plan/date; `min_los/max_los` validated against requested stay; `cta/ctd` block arrival/departure dates. Violations return coded reasons the wizard renders ("Min 2 nights on Sat").
5. **Overrides**: per‑reservation manual price (perm + mandatory reason → `reservation_daily_rates.rate_source='override'`, audit) ; group rates (§23) stamp `rate_source='group'`.

### 15.4 Rate management UI
Rate calendar (types × dates grid, plan switcher, inline edit → writes a single‑day season exception) · Bulk edit (D‑050: date range, DOW, types, set/adjust ±, restriction toggles, preview count of affected cells before apply) · Plan editor wizard (D‑051) · Derived‑link change confirmation (D‑052: shows recomputed sample week before commit).

### 15.5 Edge cases
Editing a season with existing future confirmed reservations does **not** re‑rate them (rates locked at confirm); banner offers optional "re‑rate matching reservations" bulk tool (manager, per‑reservation preview list, opt‑in). Deleting a plan with future reservations → blocked; deactivate instead (hidden from new bookings, honored for existing). Currency is fixed ETB (D‑09); the price input component formats `1,234.56` with `ETB` prefix and blocks other symbols.

## 16. Housekeeping

### 16.1 Room HK status machine (per room)
| From → To | Trigger | Actor | Notes |
|---|---|---|---|
| occupied_* → vacant_dirty | Check‑out RPC | system | Departure `hk_task` auto‑created with credits from room_type |
| vacant_dirty → (in‑progress flag) → vacant_clean | Task start/finish (mobile board) | housekeeper | Timer captured for productivity report |
| vacant_clean → vacant_inspected | Inspection pass (D‑056 checklist) | hk_supervisor | Fail → back to vacant_dirty with defect notes; optional WO spawn |
| occupied_clean → occupied_dirty | Nightly reset at audit / guest request | system/FD | Stayover tasks generated by audit per `hk.stayover_frequency` (daily/alt/none) |
| any → blocked(OOO) | Room block created (D‑057) | see §17.3 | HK tasks for range suppressed |
| vacant_inspected → occupied_clean | Check‑in RPC | system | — |
| FD "mark dirty" | Quick action | front_desk | Only towards dirty (least privilege) |

### 16.2 HK board & assignment
Supervisor board: columns by status, room chips show due‑out/arrival badges, drag to assign (bulk D‑055: pick housekeeper, auto‑balance by credits toggle). Housekeeper mobile view: my rooms ordered by priority (due‑outs with today arrivals first), one‑tap start/done, add note/photo, raise WO (D‑070 mini), lost & found (D‑058). All updates optimistic with Realtime reconciliation.

### 16.3 Discrepancy workflow
HK reports physical state (vacant/occupied/bags) vs PMS expectation → mismatch creates `hk_discrepancies` (`sleeper` = PMS vacant/physically occupied; `skipper` = PMS occupied/physically vacant). FD queue chip; resolution dialog (D‑059) forces an outcome: locate guest / correct status / open incident note / initiate skip‑out flow (folio → disputed, manager notified, DNR suggestion pre‑filled).

## 17. Maintenance & Work Orders

### 17.1 WO state machine
`reported → triaged → assigned → in_progress ⇄ on_hold → completed → verified → closed`, plus `cancelled` from any pre‑completed state (reason). Triggers/actors: anyone `mx.create` reports (D‑070 with photos, category, room/area); supervisor/manager triages (priority P1–P4 sets `sla_due_at` = now + `mx.sla_hours[P]`, defaults 4/24/72/168 h); assignee starts/holds (hold reason enum: parts/access/vendor); completes with notes+cost; verifier (`mx.close`) passes → closed, or fails → back to in_progress with comment. SLA breach → status badge + escalation notification to manager (cron `sla-watch`, 15‑min).

### 17.2 Preventive maintenance (Growth+)
`pm_schedules` (asset/area, checklist, cadence) → cron spawns WOs with `category='pm'`. v1 ships table + spawner; asset registry is P2.

### 17.3 OOO / OOS blocks
D‑057 sets kind, date range, reason, optional WO link. **OOO** removes rooms from availability (denominator too — occupancy math §25); creating an OOO overlapping assigned reservations → conflict resolver (relocate list, cannot save until zero conflicts, or shrink range). **OOS** keeps sellable (cosmetic issue) — shows wrench badge on tape chart, check‑in shows advisory. Blocks auto‑expire; extension re‑runs conflict scan. Approval flow: if `mx.ooo_requires_approval` (default ON for role maintenance), maintenance creates *pending* block → manager approves (notification + one‑click), pending blocks show hatched‑amber and do *not* affect availability until approved.

## 18. Folio, Billing & Invoicing

### 18.1 Folio state machine
`open → settled → closed`, with `reopened` (manager, reason; returns to open behavior but keeps flag) and `disputed` (checkout‑with‑balance / skip‑out; blocks close until adjustment or payment). `settled`: balance 0 at checkout. `closed`: night audit of the settle date locks it — post‑close changes only via `folio.adjust` lines dated to the *current* business_date (never rewrite history) or credit notes.

### 18.2 Posting rules (all via RPCs)
Room+tax posted nightly by audit (per in‑house reservation_room: rate from `reservation_daily_rates`, then tax block per §41.2 computation order). Manual charges (D‑041): item picker from `charge_codes` catalog (dept, default price, tax profile) or free‑form with perm. POS room‑post creates one consolidated line per ticket with drill‑down ref. Payments are negative‑sign lines mirrored in `payments`. **Void vs adjust:** same business_date + `folio.void_sameday` → void pair (original flagged, reversing line, reason); after audit → `folio.adjust` allowance line (reason enum: service_issue, price_error, goodwill, correction) — preserves the fiscal trail. Transfers (D‑042): move selected lines folio→folio (same tenant), writes matched out/in pair with cross‑refs. Split (D‑043): by lines / by percentage / room‑vs‑incidentals preset; creates sibling folio(s) under same reservation. **Routing rules** on folio (company pays room+tax, guest pays rest) are applied at posting time by matching line type → target folio; editable pre‑arrival or in‑house (D‑044), never retroactive without explicit "re‑route existing lines" checkbox that generates transfer pairs.

### 18.3 Invoices & credit notes (fiscal)
`issue_invoice` RPC: advisory‑lock property → next `invoice_seq` → snapshot header (property legal name, TIN, address; guest/company name + TIN if provided), lines, totals; render PDF (Edge `invoice-pdf`, bilingual layout, amount‑in‑words in English + Amharic); store to `invoices` bucket; email option. Invoices are immutable — corrections via credit note (D‑045: full or per‑line, reason mandatory, negative totals, own sequence share). Proforma invoices (pre‑checkout estimate) use a separate `PF-` prefix and no fiscal sequence. Fiscal‑printer/ERCA e‑invoice integration is a P2 adapter surface (`fiscal_adapter` interface: `register_invoice(payload) → {fs_no}` stored on invoice) — activation gated by §49 confirmation.

### 18.4 Company / AR folios
Company folio accumulates routed + transferred lines; statement view; AR aging report (§25); credit limit check at routing time (soft warn at 80%, block over 100% unless `folio.adjust` holder confirms). AR settlement via payment on the company folio (bank transfer typical) with allocation to open invoices (oldest‑first auto, editable).

## 19. Payments & Refunds

### 19.1 Methods & flows
| Method | Flow | Verification |
|---|---|---|
| Cash | D‑040 amount + tendered → change calc; requires open shift | Shift close reconciliation |
| Bank transfer | Record with bank + reference; status `pending` until accountant verifies (queue) → `succeeded` | `payment.verify` step; unverified transfers excluded from settle‑zero check unless flag `pay.trust_unverified_transfer` (default OFF) |
| Chapa | RPC `init_chapa_payment` → Edge creates checkout session (idempotency_key) → guest/staff completes on Chapa page or QR → `chapa-webhook` verifies signature (§49) + amount + currency=ETB → `succeeded` → folio line posted atomically | Webhook signature + `verify` API double‑check; replay‑safe by idempotency |
| Telebirr | Same pattern via `telebirr-webhook` | Same |

Payment state machine: `initiated → pending → succeeded | failed`, `succeeded → refund_pending → refunded` (or `partially_refunded` modeled as separate refund payment rows), `initiated/pending → voided` (staff cancel before completion). Timeout: pending Chapa/Telebirr sessions auto‑`failed` after `pay.session_timeout_min` (30) by cron, UI shows retry.

### 19.2 Refunds (D‑048)
Rules: refund method must match source (cash→cash from open shift; chapa→provider refund API; transfer→recorded outbound transfer with reference); amount ≤ refundable remainder (original − prior refunds); reason mandatory (enum + note); amounts > `pay.refund_approval_threshold_etb` (default 2,000) create an approval task (manager notification, D‑049 approve/reject with note) — payment sits `refund_pending`, folio shows pending badge, night audit warns (non‑blocking). Provider refund failures surface in a retry queue with error detail; manual override "mark refunded externally" requires manager + reference.

### 19.3 Reconciliation surfaces
Daily payments journal by method/shift; Chapa/Telebirr settlement report vs provider export (CSV import matcher, unmatched rows queue); transfer verification queue; over/short ledger. All feed the night‑audit cashier pack.

## 20. Night Audit

### 20.1 Purpose & invariants
Closes the hotel day: converts expected states into facts, posts room & tax, advances `business_date`. Invariants: exactly one run per (property, date) (§11.2); every step idempotent (re‑run skips completed sub‑items via natural keys, e.g., room posting keyed on (reservation_room, date)); a failed run is resumable from the failed step; while `running`, mutation RPCs that would change that date's facts (check‑in/out, postings) are blocked with `AUDIT_IN_PROGRESS` (friendly toast + banner).

### 20.2 Wizard steps (D‑078, executed by `audit.run` holder)
| Step | System does | Operator resolves | Block/Warn |
|---|---|---|---|
| 0 Preconditions | Scan: unresolved expected departures; expected arrivals neither checked‑in nor no‑show; open cashier shifts; open POS tickets/day not closed; pending room moves | Deep links per item | **Block** until list empty (each item resolvable inline) |
| 1 No‑shows | Lists remaining arrivals | Per row: mark no‑show (fee preview) / extend to tomorrow / cancel‑waive (perm) | Block until decided |
| 2 Room & tax posting | Preview matrix (rooms × amount × tax) totals; then post batch in one txn | Review anomalies (0‑rate rows highlighted; require override ack) | Warn on 0‑rate; block on missing daily rate (data bug ⇒ fix via override dialog) |
| 3 Stayover HK seed | Generates tomorrow's stayover tasks + resets occupied_clean→occupied_dirty per policy | — | — |
| 4 Date rollover | Single txn: `business_date += 1`; write run totals snapshot | — | Point of no return banner + typed confirm ("ADVANCE") |
| 5 Reports pack | Manager flash, dept revenue, cashier summary, arrivals list for new date → PDFs to storage + email list `audit.report_recipients` | Download links | Failures here don't roll back date; retry per report |

Failure semantics: any step error → run `failed` with step detail; banner on FD dashboard "Audit for {date} incomplete — resume"; resume re‑enters at failed step. If audit not run by 06:00, escalation notification to manager (cron `audit-watch`). Multi‑property tenants run per property independently.

## 21. POS (F&B) — module flag `module.pos`

Outlets → menu (categories/items, bilingual names, modifiers as jsonb options with price deltas) → tickets. Ticket machine: `open → (lines added/voided) → room_posted | paid | void`. Room post (D‑066): search in‑house by room/name → confirm identity (guest name + room shown large, optional signature capture toggle `pos.capture_signature`) → posts consolidated folio line, ticket locks. Direct pay uses D‑040 within POS shift. Void line requires `pos.void` + reason (waste/comp/error), after‑send voids flagged for day‑close review. Day close (D‑067 wizard): all tickets closed check → sales summary by category/payment → variance ack → marks POS day closed (feeds audit precondition). Kitchen printing out of scope v1 (tickets screen refresh via Realtime).

## 22. Guest CRM

Profile completeness meter; Ethiopian address block (Region→Zone→Woreda→Kebele cascading selects from seeded `et_admin_divisions` reference table) or international block; ID capture; preferences chips; stay/spend stats auto‑rolled. **Dedupe:** on create/edit, matcher scores phone (exact, normalized +251), email, id_number, name+dob fuzzy; score ≥ threshold → suggestion panel; merge (D‑062, `guest.merge`): pick survivor, field‑level conflict picker, re‑points FKs in one txn, loser tombstoned with redirect. **DNR** (D‑063): level warn/block + reason + evidence link; lifting requires manager + note; DNR checks fire at reservation create and check‑in (G6). **Privacy:** export (JSON+PDF of profile, stays, folios) and anonymize (D‑064: irreversibly scrubs PII, keeps financial aggregates under `Guest‑{hash}`) — anonymize blocked while future reservations or open balances exist.

## 23. Groups & Allotments — flag `module.groups`

Block wizard (D‑016): name, company, dates, per‑type nightly allotment grid, group rate (flat/plan‑linked), cutoff date, billing mode (master pays all / master pays room+tax / individual). States: `tentative` (holds inventory softly, dashed on charts) → `definite` (hard block) → auto **cutoff release** (cron returns unpicked allotment to general availability, notification to sales owner) → `cancelled` (release all; cancellation terms noted). Pickup: rooming‑list import (D‑017 CSV wizard: template download, column mapping, row validation report, partial‑accept with error file) or manual pickup from group page (creates reservations `source='group'`, rate_source='group', routing per billing mode). Master folio behaves per §18.4.

## 24. Channel / OTA Connectivity — flags `module.channel_ical`, `module.channel_api`

**iCal (Growth+):** per room‑type export URL (availability busy‑blocks) + import URLs (Booking.com/Airbnb style). `ical-sync` cron (10‑min): fetch → diff → create/cancel `source='ota'` reservations (guest stub from summary; rate = mapped plan or channel amount if present). **Conflict queue:** import causing negative availability or physical clash → reservation created *unassigned* + `channel_sync_log.conflict` → red badge queue; resolution dialog offers relocate/upgrade/deny (deny drafts an email to channel contact — manual send, we never auto‑cancel an OTA booking). **Channel‑manager API (Pro):** adapter interface `push_availability/push_rates/pull_bookings` with a reference webhook adapter; concrete CM chosen per market (§49). Rate parity report compares channel rate vs BAR.

## 25. Reports & Analytics

Definitions (fixed formulas — tested):
`rooms_available(d) = physical_active − OOO(d)` · `occ% = rooms_sold/rooms_available` · `ADR = room_revenue/rooms_sold` · `RevPAR = room_revenue/rooms_available` (room_revenue = folio_lines type room, net of voids, **excluding** taxes & service).
Catalog: Manager Flash (daily/MTD/YTD, vs last year; EC‑month grouping toggle `calendar.report_grouping`) · Forecast 30/90 (on‑books + pickup pace) · Arrivals/Departures/In‑house lists (printable) · HK productivity & room status summary · Maintenance SLA & aging · Revenue by department & charge code · Payments journal & method mix · Cashier shift pack · AR aging (30/60/90) · No‑show/Cancellation analysis · Group pickup vs block · Rate override log · Audit pack archive. All reports: property + date‑range params, ETB formatting, CSV + PDF export, Growth+ scheduled email (D‑074 schedule dialog: cadence, recipients, format). Dashboards render with Recharts; heavy aggregates come from SQL views (`v_daily_stats` materialized nightly by audit step 5).

## 26. Notifications & Messaging

Outbox pattern: producers insert `notifications_outbox`; Edge `notify-dispatch` (queue trigger + 1‑min sweep) renders template (per‑tenant override else system default; locale from recipient) and sends via provider adapter; retries 1m/5m/30m/2h then `dead` (+ ops alert). Template registry (system keys): `booking_confirmed`, `booking_cancelled`, `pre_arrival_reminder` (T‑1 day cron, flag), `invoice_issued`, `refund_processed`, `noshow_notice`, `wo_assigned`, `wo_sla_breach`, `audit_complete_pack`, `shift_over_short`, `user_invited`, `saas_invoice`, `saas_dunning_1/2/3`, `announcement`. Editor (D‑072): variable palette with insert‑at‑cursor, live preview with sample data, per‑locale tabs (en/am), test‑send to self; system templates clone‑on‑edit (reset‑to‑default action). SMS length counter warns >1 segment (GSM vs Ethiopic UCS‑2 segments computed correctly — Amharic = 70 chars/segment). Per‑tenant sender identity: email from `notifications@engida.et` with reply‑to tenant email v1 (custom domain P2); SMS sender ID registration tracked per tenant (§49). In‑app: bell feed + Realtime toast for actionable events (approval requests, conflicts, SLA).

---

# PART E — OPERATIONS & PLATFORM ADMINISTRATION

## 27. Super‑Admin Console (`/platform`, platform roles only)

### 27.1 Surfaces
Tenants list (status, plan, properties, rooms, MRR, last activity, health dot) → Tenant detail (subscription, usage vs limits, feature overrides, members, recent audit slice, billing history, danger zone) · Plans & pricing editor · SaaS invoices & transfer‑proof approval queue · Announcements composer (D‑077) · Platform health dashboard (§30) · Backups (§32) · Flag overrides · Support tools (resend invite, unlock user, force claim refresh).

### 27.2 Tenant provisioning (D‑075 wizard)
Steps: company info (name, TIN, address block, contacts) → plan + trial length (`saas.trial_days` default 14) → first property (name, code, rooms count seed?, times, tax defaults) → owner invite. On finish, a Postgres `provision_tenant` RPC creates tenant, property, default roles/permissions link, default settings snapshot, charge‑code catalog seed, templates, and sends the owner invitation — all one transaction; failure leaves nothing.

### 27.3 Danger zone actions
Suspend (D‑076a confirm with reason → status suspended, tenant read‑only §28.3) · Reactivate · Cancel (end of period) · **Purge** (only after `cancelled` + `saas.purge_after_days` (90): D‑076b double confirmation — type tenant name + checkbox "final export downloaded" (link to generate §32.3 export) → `purge_scheduled` → cron hard‑deletes rows + storage after 72‑h cooling window; irreversible, fully audited).

### 27.4 Impersonation (support access)
D‑073: pick tenant → property → role to assume (default manager, read‑only toggle default ON) → mandatory reason (ticket ref) → mints time‑boxed token (Edge `mint-impersonation`, ≤ 60 min) with `imp` claim. During session: persistent red banner "Support session as {tenant} — {mm:ss} — [End]"; every action lands in tenant `audit_log` with `impersonated_by`; tenant owner receives a summary notification (flag `platform.notify_on_impersonation`, default ON). Read‑only mode blocks all mutation RPCs at the guard level (`imp.ro=true`).

## 28. SaaS Subscription Lifecycle & Dunning

### 28.1 State machine
| From → To | Trigger | Effect |
|---|---|---|
| trial → active | First SaaS payment approved | Full plan features |
| trial → suspended | Trial ends unpaid (+`saas.trial_grace_days` 3) | Read‑only |
| active → past_due | Invoice unpaid at due date | Banner + dunning emails day 0/3/7 (`saas_dunning_*`); features intact |
| past_due → active | Payment approved | Clear |
| past_due → suspended | `saas.grace_days` (10) exceeded | Read‑only + owner‑only billing access |
| suspended → active | Payment | Restore |
| any → cancelled | Owner request or platform | Runs to period end, then read‑only 30 d |
| cancelled → purge_scheduled → purged | §27.3 | Data destroyed |

### 28.2 Billing ops (manual‑first, D‑14)
Monthly cron `saas-invoicer` issues `saas_invoices` (ETB, plan price × properties where applicable); tenant owner pays by bank transfer and uploads proof (tenant Settings → Billing, D‑071 upload) → platform approval queue (approve/reject with note) → payment recorded. Chapa recurring (P2) replaces the manual leg per tenant when enabled.

### 28.3 Read‑only mode (tenant_status ∈ {suspended, trial‑expired})
Global amber/red banner with pay CTA (owner) / "contact owner" (staff); every mutation RPC guard rejects with `TENANT_READONLY`; UI pre‑disables primary actions; reads, exports, and the owner's billing pages remain available. In‑house guests are never trapped: `frontdesk.checkout` + `payment.take` remain enabled for 7 days post‑suspension (humane wind‑down window, flag `saas.suspension_ops_grace_days`).

## 29. Feature Flags & Configuration Registry (complete)

Precedence: tenant override > plan default > platform default. Evaluated by `app.flag(key)` (SQL) and a typed `useFlag(key)` hook (client, from a single `/settings/effective` query, cached, Realtime‑invalidated). Changing any key writes audit `settings.changed` with before/after. **Registry (authoritative — adding a key requires a row here):**

| Key | Scope | Type / default | Meaning |
|---|---|---|---|
| module.pos / module.groups / module.channel_ical / module.channel_api / module.guest_portal / module.api | plan | bool per §1.6 | Module gates |
| limits.properties / limits.rooms / limits.users / limits.pos_outlets | plan | int per §1.6 | Hard limits (enforced at create RPCs; friendly upsell dialog D‑006) |
| res.hold_ttl_minutes | property | int 60 | Hold expiry |
| res.allow_overbooking | property | bool false | Enables D‑015 path |
| res.deposit_required | rate‑plan | enum none/first_night/pct/flat (+value) | Deposit policy |
| res.fd_rate_override | property | bool false | Front desk may override rates |
| ops.checkin_room_requirement | property | enum any/clean/inspected = clean | Guard G3 |
| ops.early_checkin_from | property | time 10:00 | Early check‑in window start (prev‑day arrival) |
| ops.early_checkin_fee / ops.late_checkout_fee | property | {mode: flat|pct_night, value} / null=off | Auto‑proposed fee lines |
| ops.late_checkout_grace_min | property | int 60 | Grace before late fee |
| ops.max_checkout_balance_etb | property | numeric 0 | Cap for checkout‑with‑balance |
| ops.room_move_rerate | property | enum keep/new_from_move = keep | Room‑move pricing |
| hk.inspection_required | property | bool true | Adds inspected step before sellable if G3=inspected |
| hk.stayover_frequency | property | enum daily/alternate/none = daily | Audit task seeding |
| hk.restrict_to_assigned | property | bool true | Housekeepers touch only assigned rooms |
| mx.sla_hours | property | jsonb {P1:4,P2:24,P3:72,P4:168} | SLA clocks |
| mx.ooo_requires_approval | property | bool true | Pending‑block approval flow |
| billing.vat_rate | property | numeric 0.15 | §41 |
| billing.vat_inclusive | property | bool false | Price entry semantics |
| billing.service_charge_rate | property | numeric 0.10 (nullable=off) | Service charge |
| billing.levy_rate | property | numeric 0 (until §49) | Tourism/city levy |
| billing.auto_invoice_on_checkout | property | bool true | §14.3 |
| billing.fx_reference_display | property | bool false | Read‑only FX hint (rate source manual daily entry) |
| pay.methods_enabled | property | set {cash, transfer, chapa, telebirr} | Method toggles |
| pay.chapa_keys / pay.telebirr_keys | property (secret) | encrypted refs | Stored in Vault‑style `secrets` table, service‑role read only |
| pay.refund_approval_threshold_etb | property | numeric 2000 | §19.2 |
| pay.trust_unverified_transfer | property | bool false | §19.1 |
| pay.session_timeout_min | property | int 30 | Provider session TTL |
| pos.capture_signature | property | bool false | Room‑post signature |
| guest.id_required_checkin | property | bool true | Guard G5 |
| group.fd_manage | property | bool false | FD may manage groups |
| calendar.dual_display | tenant | bool true | GC+EC everywhere |
| calendar.report_grouping | tenant | enum gc/ec = gc | Report month basis |
| locale.default | tenant | enum en/am = en | New‑user default |
| security.mfa_required_roles | tenant | set = {owner} (+platform enforced) | §5.1 |
| security.session_idle_minutes | tenant | int 30 | §5.3 |
| notify.pre_arrival_reminder | property | bool true | T‑1 message |
| audit.report_recipients | property | email[] | Step‑5 pack |
| saas.trial_days / saas.grace_days / saas.purge_after_days / saas.suspension_ops_grace_days | platform | 14 / 10 / 90 / 7 | Lifecycle |
| platform.notify_on_impersonation | platform | bool true | §27.4 |

Settings UI groups these into pages (Property → Operations / Billing & Tax / Payments / Housekeeping / Maintenance / Notifications; Tenant → General / Localization / Security / Billing); risky changes (tax rates, vat_inclusive, methods) confirm via D‑068 with "applies to future postings only" notice.

## 30. Monitoring & Observability

**Client:** Sentry (errors + performance; release tagging from git SHA; user context = user_id/tenant_id only, no PII); Web Vitals to Sentry; feature‑level timing marks (check‑in duration → G2 metric). **Edge Functions:** structured JSON logs (level, fn, tenant_id, correlation_id, duration); errors → Sentry (Deno SDK). **Database:** `pg_stat_statements` reviewed weekly; slow‑query log > 500 ms; connection/CPU/storage alerts via Supabase → webhook → ops channel. **Synthetic checks:** external uptime monitor hits `/health` (static) and Edge `health` (DB round‑trip + outbox depth + oldest queued notification age) every minute from 2 regions. **Business health alerts (cron `ops-watch`):** audit not run by 06:00 (per property) · outbox dead > 0 · webhook failures > 3/h · payment pending > 45 min · channel sync errors · backup job failure. Alert routing: email + ops Telegram webhook; severity ladder S1 (payments/auth down) page immediately, S2 within 1 h, S3 daily digest. Dashboards: platform health page renders these signals + per‑tenant last‑audit heatmap.

## 31. Logging & Audit Trail

Levels: `audit_log` (business truth, §10 #50) vs technical logs (Sentry/Edge). Audit coverage rule: **every state transition, every money line, every permission‑gated action, every settings/flag change, every auth‑sensitive event** (login failure spikes summarized, MFA changes, impersonation start/end) writes exactly one audit row from inside the same transaction. Insert‑only enforced by `revoke update, delete` + no policies; partitions monthly; retention §33. Tenant UI: History tab on each entity + global Audit Log screen (`audit_log.read`) with filters (actor, action, entity, date) and export; financial actions additionally surfaced in accountant views. Correlation: RPCs stamp `correlation_id` (uuid per user action) shared with Edge logs and client Sentry breadcrumbs — one ID traces a check‑in across all layers.

## 32. Backup & Restore

### 32.1 Layers
1. **PITR** — Supabase Point‑in‑Time Recovery (7‑day window minimum) on staging+prod: RPO ≤ 2 min for whole‑project disasters.
2. **Nightly logical dumps** — cron Edge `backup-export` runs `pg_dump` (custom format) via Supabase management API → `backups` bucket → mirrored off‑platform to Cloudflare R2 (rclone in the same job); checksum + size recorded in `backups`; 30 daily + 12 monthly retained.
3. **Tenant‑level export** — on‑demand RPC+Edge `tenant-export`: all tenant rows as CSV per table + storage files manifest, zipped, signed URL emailed to requester (owner or platform); used pre‑purge and for offboarding.

### 32.2 Restore runbooks (rehearsed quarterly on staging — calendar item)
Whole‑project: PITR restore to new project → repoint staging frontend → validate checklist (row counts, latest audit runs, sample invoice PDF) → DNS/env switch if promoting. Single‑tenant logical restore: `pg_restore` dump into scratch schema → targeted `insert … select` of tenant rows in FK order (scripted `restore_tenant.sql`) → re‑run balance cache + stats triggers. Accidental‑deletion (soft‑delete era): un‑tombstone via admin tool; hard cases fall back to scratch‑schema copy. Each runbook lives in `/ops/runbooks/*.md` in the repo with exact commands.

### 32.3 Verification
`backup-verify` weekly cron restores the newest dump into a temp database, runs `select count(*)` fingerprints vs source, and posts result to ops channel — a backup that isn't test‑restored is treated as nonexistent.

## 33. Data Lifecycle & Retention

| Data | Retention | Then |
|---|---|---|
| Financial (folios, lines, payments, invoices, audit financial actions) | 10 years (Ethiopian bookkeeping practice; verify §49) | Archive partition export + purge |
| Guest PII (profile, ID images) | 2 years after last stay (config `retention.guest_years`) | Anonymize job (keeps aggregates) |
| Operational (hk_tasks, WOs, pos tickets) | 3 years | Purge partitions |
| Audit log (non‑financial) | 3 years | Export to cold storage, drop partition |
| Notifications outbox | 90 days | Drop |
| Backups | per §32.1 | Rotate |
Jobs run monthly (`retention-sweeper`), dry‑run report first, destructive pass 7 days later; every purge summarized in platform audit.

---

# PART F — UI SPECIFICATION

## 34. Design System & Global UI Standards

**Tokens (Tailwind theme):** `--primary` deep indigo `#1E2A4A`; `--accent` Harar gold `#C8942A`; surfaces warm white `#FAFAF7` / card `#FFFFFF`; semantic: success `#1B7F4C`, warning `#B7791F`, danger `#B3261E`, info `#2563EB`. Status hues are fixed contracts reused everywhere (tape chart, pills, boards): hold=amber outline, confirmed=blue, in‑house=green, checked‑out=slate, cancelled=grey strikethrough, no‑show=red, OOO=hatched red, OOS=hatched amber, dirty=red dot, clean=amber dot, inspected=green dot. **Type:** Public Sans (UI) + Inter (numeric tables, `font-variant-numeric: tabular-nums`); Noto Sans Ethiopic auto‑applied for Amharic strings. **Density:** comfortable default; compact toggle for FD/HK boards. **Numbers:** ETB always as `ETB 12,345.67` (component `<Money/>` — the only allowed way to render amounts); dates via `<StayDate/>` rendering `Tir 12, 2018 EC · 20 Jan 2026` when `calendar.dual_display`. **Empty/loading/error** states standardized per screen (skeleton → content; empty = icon + one‑line + primary CTA; error = retry + D‑007 link). **Toasts:** success 4 s, error sticky with action; never used for information the user must act on later (those go to the bell feed).

## 35. Application Shell & Navigation Map

Left sidebar (role‑filtered, collapsible; Amharic labels via i18n):
```
Dashboard | Front Desk (Arrivals · Departures · In‑House · Tape Chart)
Reservations (List · Calendar · Groups*) | Guests | Housekeeping (Board · Tasks · Lost&Found)
Maintenance | POS* (Outlets · Day Close) | Billing (Folios · Invoices · Payments · AR · Shifts)
Rates (Calendar · Plans · Restrictions) | Reports | Channels* | Settings | [Night Audit ▶]
/platform (platform roles): Tenants · Plans · Billing · Health · Backups · Announcements
```
Top bar: property switcher (D‑008) · business‑date chip · global search ⌘K (D‑009) · bell · user menu (language en/አማ, profile, MFA, sign out). Route guards: TanStack Router `beforeLoad` checks session + permission per route; unauthorized → D‑004 page variant. Deep links are canonical (`/reservations/:id`, `/folios/:id`) — every queue row, toast action, and notification links here.

## 36. Dialog Framework Standards (apply to every D‑0xx)

1. Built on shadcn `Dialog`/`AlertDialog`/`Sheet`; focus trapped; initial focus = first field (or Cancel for destructive); `Esc`/overlay‑click closes **only** pristine dialogs — dirty state routes to D‑001; `Enter` submits single‑field forms only.
2. Primary action right, secondary left; destructive primaries are red and never the default focus. Buttons show spinner + disable on submit (double‑click safe); all mutating dialogs pass `idempotency_key`.
3. Validation: Zod schema shared with server; inline errors on blur + on submit; server field errors map back to fields; non‑field errors render in a dialog‑level alert strip.
4. Async success: close → toast → cache invalidation (TanStack keys listed per dialog in code); failure: dialog stays open, values preserved.
5. Long dialogs (>70 vh) become side `Sheet`s; wizards keep a step rail, validate per‑step, allow back without loss, and persist draft in memory (not storage) until closed.
6. Destructive irreversible actions use the **type‑to‑confirm** pattern (D‑002) + reason where audited.
7. Every dialog is keyboard‑completable and screen‑reader labeled (`aria‑describedby` = consequence sentence); all copy exists in en+am resource files.
8. Concurrency: dialogs embed `expected_updated_at`; on `P0409` → D‑005 flow.
9. Offline: submit while offline → non‑blocking "reconnecting" banner inside dialog, auto‑retry 3× then persistent error with manual retry (no silent loss).

## 37. Dialog Catalog

IDs are banded per domain; unused numbers in a band are reserved for future dialogs. Each entry: **type · trigger → content/fields → validation → actions → success → edge cases.**

### 37.1 Global & system (D‑001 – D‑009)

**D‑001 Unsaved Changes** · alert · closing dirty dialog/route‑leave. Body names the artifact ("Discard this reservation draft?"). Actions: Keep editing (default) / Discard (red). Edge: browser tab close also guarded via `beforeunload` on dirty wizards.

**D‑002 Destructive Confirm (pattern)** · alert · any irreversible/high‑impact action without its own dialog (deactivate room, delete template, revoke invite, deactivate member, delete rate season, revoke API key). Content: consequence list (auto‑generated impact counts where cheap, e.g., "3 future tasks will be unassigned"); reason field when audited; type‑to‑confirm (entity name) when irreversible. Edge: impact query failure → still allow with generic warning, log.

**D‑003 Session Expiry** · alert, non‑dismissable · idle timer hits limit −120 s. Countdown mm:ss; Actions: Stay signed in (refresh session) / Sign out. Edge: refresh fails (offline) → switches to "Reconnect" state, retries; countdown reaching 0 signs out and routes with `?reason=idle`; any in‑dialog activity does *not* reset (explicit choice required).

**D‑004 Permission Denied** · alert (or page for routes) · RPC `AUTHZ_DENIED` / guard. Shows required permission name in plain language; Actions: OK; "Request access" (drafts in‑app message to managers, throttled 1/permission/day). Edge: role changed mid‑session → also forces claim refresh so UI re‑renders correctly.

**D‑005 Record Changed** · alert · optimistic‑concurrency `P0409`. Shows who saved and when (from row meta); Actions: Reload (default; re‑opens dialog with fresh values + my values preserved in a diff panel) / Overwrite (perm‑holders only, audited). Edge: record deleted meanwhile → variant "no longer exists" → close + list refresh.

**D‑006 Plan Limit Reached** · modal · create RPC hits `limits.*`. Shows current/limit, plan comparison mini‑table, CTA "Request upgrade" (notifies owner + platform) — never a dead end: offers "deactivate an existing X" link where sensible. Edge: owner sees direct upgrade path; staff see request‑only.

**D‑007 Error Details & Report** · modal · from error toast "Details". Shows human message, code, correlation_id (copy button), safe context; Action: "Send report" (bundles Sentry event id + user note). Never shows stack traces or SQL.

**D‑008 Property Switcher** · command modal · top‑bar / post‑login when >1 property. Search list with role badge per property; selection persists per device; switching mid‑dirty‑form triggers D‑001 first. Edge: property became inaccessible → removed live with toast.

**D‑009 Command Palette** · command modal · ⌘K / "/" . Scopes: navigation, guests (by name/phone), reservations (conf no), rooms, actions ("New walk‑in"). Respects permissions; recent items; Amharic search normalizes Ethiopic/Latin digits. Edge: >200 ms queries debounced; offline → local nav only.

### 37.2 Auth & account (D‑026 – D‑028)

**D‑026 MFA Enrollment** · wizard (3) · user menu, or forced interstitial when role requires MFA and none enrolled (cannot dismiss, "later" allowed only within `security.mfa_grace_days`=7). S1 QR + manual secret; S2 verify 6‑digit (drift ±1 step accepted); S3 recovery codes (download/print, checkbox "I stored these" required). Edge: wrong code 5× → 5‑min cooloff; re‑enrollment invalidates old factors after new verify succeeds (never a lockout gap).

**D‑027 MFA Challenge** · modal during login · after password success for enrolled users. 6‑digit input, "use recovery code" link (single‑use, burns code, warns when ≤2 left → banner to regenerate). Edge: 5 failures → lockout 15 min; challenge expires with session attempt after 5 min → restart login.

**D‑028 Change Password** · modal · profile / forced on admin "require reset". Current + new + confirm (Zod policy meter); success invalidates other sessions (GoTrue global sign‑out) with notice. Edge: current wrong → field error, attempts rate‑limited.

### 37.3 Reservations & groups (D‑010 – D‑019)

**D‑010 New Reservation** · wizard (5, Sheet) · +New, tape‑chart drag, dashboard. **S1 Stay:** property (if multi), arrival/departure (range picker, dual GC/EC display, min 1 night), adults/children, room‑type availability grid live (`v_availability`), rate plan per type with nightly price preview + restrictions verdicts inline. **S2 Guest:** search‑or‑create (dedupe chips §22; DNR warn chip inline), company link optional. **S3 Options:** room preference/auto‑assign toggle, notes, add‑ons (extra bed/airport pickup from charge codes), ETA. **S4 Payment/guarantee:** policy readout (deposit due, cancel terms rendered from `cancel_policies` in words); [Hold {TTL} min] or take deposit now → embeds D‑040. **S5 Review** → Create. Validation per step; total recalcs on any change. Success: detail page + toast with conf no + send‑confirmation toggle (default on if guest has email/phone). Edge: availability lost between S1 and submit → server re‑check fails → return to S1 with the conflicting nights highlighted and alternatives (other type/dates ±1); zero availability + `res.allow_overbooking` → D‑015 branch; guest is DNR‑block → hard stop with manager‑override hand‑off; price changed since S1 (rate edit race) → diff banner requiring re‑ack.

**D‑011 Edit Stay Dates** · modal · reservation detail "Change dates". New range picker; server `preview` returns availability verdict + re‑rate diff table (old vs new nightly, delta total). Confirm applies atomically. Edge: shrink below posted nights → blocked with "use Early departure (D‑034)"; extension partially available → offer split‑with‑room‑move plan (renders the two segments) or cancel.

**D‑012 Cancel Reservation** · modal · detail/list action. Shows policy evaluation: hours to arrival, computed fee (or 0) with the matching rule quoted; reason select + note; if fee>0, "post fee now" (default) with folio target. Outside policy: fee editable/waivable only with `reservation.cancel.override` (reason mandatory, audited). Confirm = red "Cancel booking" (type‑to‑confirm when fee waived >1,000 ETB). Success: status pill update, message send toggle. Edge: already checked‑in → action absent (would be early departure); OTA‑sourced → warning "cancel on the channel too" with channel ref copy.

**D‑013 Mark No‑Show** · modal · audit step 1 / detail (business_date>arrival). Fee preview per policy; note; option "convert to cancelled instead". Edge: deposit on file → shows applied‑to‑fee math; guest actually arrived later same night → use Reinstate.

**D‑014 Reinstate** · modal (manager) · from cancelled/no_show/checked_out. Availability re‑check result shown; fee reversal checkbox (posts adjustment); for checked_out: only same business_date, reopens folio. Edge: room re‑let → forces new assignment step inline.

**D‑015 Overbooking Acknowledgment** · alert inside D‑010 · availability < 1 with flag on. Shows current overbook depth vs allowance per date; requires checkbox "I understand this may require a walk" + note; audit `reservation.overbook_ack`. Edge: allowance exhausted → hard stop (only `inventory_adjustments` edit by manager raises it).

**D‑016 Group Block** · wizard (4) · Groups +New. S1 basics (name, company, dates, cutoff, status tentative/definite); S2 allotment grid (types × nights, paste‑fill, totals); S3 rates (flat per type or link plan ±); S4 billing mode + review. Edge: allotment beyond availability → per‑cell red with cap suggestion; definite blocks write hard inventory (validated transactionally).

**D‑017 Rooming List Import** · wizard (3) · group page. S1 upload CSV/XLSX (template download link); S2 column mapping with auto‑guess + per‑row validation table (errors: unknown type, over allotment, bad dates, dup guest) — toggle "import valid rows only"; S3 result summary + error file download. Edge: re‑import updates by external_ref key instead of duplicating; mid‑import failure is transactional per row batch with resumable cursor.

**D‑018 Extend Hold** · popover‑modal · holds queue. Shows expiry, +30/+60 min (max 2 extensions, then manager). Edge: already expired → offer re‑create with fresh availability.

**D‑019 Break Hold** · alert (manager) · room/type needed. Shows hold owner + guest + expiry; reason; on confirm, hold → expired, creator notified in‑app. Edge: hold converts to confirmed mid‑dialog → D‑005 variant.

### 37.4 Front desk & stay (D‑030 – D‑039)

**D‑030 Check‑In Wizard** · wizard (4, Sheet) · Arrivals queue row, reservation detail, tape chart. **S1 Verify stay:** dates/type/rate readout, guard table §14.2 evaluated live — each failed guard renders as a red row with its resolution CTA inline (assign room → mini room picker filtered to type+clean; not clean → D‑036; DNR warn → D‑037; deposit due → embeds D‑040). Cannot advance until all guards green or overridden. **S2 Guest & registration:** confirm identity fields, capture/verify ID (photo upload → `guest-ids` bucket, doc type + number required if `ops.require_guest_id`), companions add, vehicle plate optional. **S3 Keys & preferences:** room shown large with floor/features, key count (logged), special requests to HK note. **S4 Registration card:** rendered preview (D‑038) — print or "signature on paper" checkbox → Complete. Server `check_in` RPC re‑runs all guards atomically. Edge: room taken between S1 and submit (race) → P0409‑style return with next‑best clean room suggestion; reservation for tomorrow with `ops.allow_early_checkin` → posts early arrival fee line option; group member check‑in offers "check in others from this group" chain; mid‑wizard session expiry → D‑003 preserves state.

**D‑031 Walk‑In Express** · modal (single screen) · dashboard quick action. Collapsed one‑form: nights (default 1) + room type grid with live price, guest quick‑create (name+phone min), payment now (embeds D‑040, cash default) → creates reservation **and** checks in atomically (`walk_in` RPC). Link "more options" expands into full D‑010→D‑030 chain. Edge: no clean rooms of type → shows inspect‑pending rooms with supervisor call‑to‑action; phone matches existing guest → attach chip (avoids dupe); DNR match → same G6 handling, no shortcut.

**D‑032 Room Move** · modal · in‑house reservation, tape‑chart drag. Target room picker (same type default; other type shows rate implication per `ops.room_move_rerate` = keep_rate | new_rate_from_move_date, per‑move override with perm `rate.override`). Reason select (guest request / maintenance / upsell / operational). Effect preview: old room → vacant_dirty + HK task now; new room must satisfy clean rule (same D‑036 override path). Confirm executes `move_room` RPC. Edge: move on departure day → warned "consider late checkout instead"; moving into a room with arrival tonight → blocked with conflict details; upsell with price increase → optional "collect difference now" embeds D‑040.

**D‑033 Check‑Out & Settlement** · wizard (3, Sheet) · Departures queue, folio page. **S1 Review folio:** grouped lines (room/tax/POS/other), disputed lines flagged; blocking list: open POS tickets (deep links, "post all" bulk action with perm), pending refund approvals (warning only). **S2 Settle:** balance figure large; if >0 → embedded D‑040 (multi‑payment allowed until 0); if <0 (credit) → refund path D‑048 or "leave on account" (company folio transfer, perm‑gated); zero → skip. Late‑checkout fee auto‑proposed row per §14.3 (D‑035 editor). **S3 Confirm:** invoice issue toggle (default per `billing.auto_invoice_on_checkout`), email/SMS receipt toggles, "guest departed" → `check_out` RPC. Edge: balance ≠ 0 + actor holds `frontdesk.checkout_with_balance` and |bal| ≤ cap → AR transfer inline (company required); company missing → create‑company mini‑form; checkout after midnight pre‑audit → posts to current business_date with banner; group master folio settles member folios in sequence with progress list.

**D‑034 Early Departure** · modal · in‑house, new departure < original. Date picker (≥ today); re‑rate mode radio per `ops.early_departure_rerate` (keep posted nights as‑is / re‑rate whole stay at new LOS price — shows diff); optional early‑departure fee line (default from `ops.early_departure_fee`, editable with perm); releases remaining nights' inventory on confirm, then flows into D‑033. Edge: departure = today → skips date picker; OTA reservation → advisory to update channel.

**D‑035 Late Check‑Out Fee** · popover‑modal · from D‑033 S2 or in‑house actions. Shows checkout deadline, current time, computed fee (`ops.late_checkout_fee` flat or % of night); editable amount with `rate.override` (reason); "waive" with perm + reason. Posts a dated folio line. Edge: property grace window not yet exceeded → dialog opens in "schedule for later" informational mode.

**D‑036 Not‑Clean Override** · alert · from G3 failure in D‑030/D‑032. Shows room's HK status + last update + assigned housekeeper; requires reason note; actor needs `hk.inspect` or manager role. Confirm marks room `vacant_clean` (flagged `override=true` in `room_status_log`) and notifies HK supervisor. Edge: status flips to clean while dialog open (Realtime) → auto‑resolves with toast.

**D‑037 DNR Acknowledgment** · interstitial alert · G6 warn‑level match at reservation create or check‑in. Full‑width amber panel: DNR reason, set‑by, date, evidence link (perm‑gated view); requires checkbox "I have read the note" + optional comment → audit `guest.dnr_bypass`. Block‑level renders the same panel red with **no** proceed button — only "Request manager override" (sends approval notification; manager approval converts to warn for this stay only). Edge: merged‑guest DNR inherited → shows origin profile.

**D‑038 Registration Card Preview** · modal · D‑030 S4, reservation detail reprint. Bilingual (en/am) A5 layout: property legal header + TIN, guest + ID snapshot, stay/rate summary, policy fine‑print from `settings.regcard_terms`, signature box. Actions: Print, Download PDF, "signed copy stored" checkbox (uploads scan optional). Edge: unpriced OTA rate → prints "rate as per booking channel".

**D‑039 Extend Stay** · modal · in‑house actions. New departure picker; availability verdict per night (partial → offers room‑move split identical to D‑011); rate preview for added nights (current plan resolve); confirm posts nothing (audit will post nightly) but re‑guarantees deposit if policy requires (embeds D‑040 for top‑up). Edge: extension collides with OOO block → conflict panel; guest on company routing → added nights inherit routing.

### 37.5 Folio, cashier & payments (D‑040 – D‑049)

**D‑040 Take Payment** · modal (embeddable) · folio, wizards, POS. Amount (defaults to balance; editable ≤ balance unless deposit context), method tabs per enabled `pay.methods`: **Cash** (tendered → change calc big‑font; requires open shift else inline "Open shift" → D‑046), **Bank transfer** (bank select from property accounts, reference no. required, proof photo optional), **Chapa/Telebirr** (generates checkout link/QR; dialog enters *awaiting* state with live webhook status via Realtime; manual "mark paid" hidden unless `pay.manual_confirm` + perm, reference mandatory). Success: receipt row + print/SMS toggles. Edge: webhook confirmed after dialog closed → toast + folio auto‑refresh (idempotent); double‑click protection via client idempotency key; partial payments loop until balance 0; currency is ETB‑only — foreign cash converted outside system, note field encouraged (§49 forex).

**D‑041 Post Charge** · modal · folio "+Charge". Charge‑code picker (dept groups, search, favorites per user), qty × unit (price prefilled, editable with `folio.post.custom`), tax profile auto from code (override perm‑gated), date (defaults business_date; back‑dating blocked post‑audit), note. Free‑form item requires `folio.post.custom`. Edge: folio settled/closed → action hidden (reopen path §18.1); negative amounts blocked (use void/adjust/credit note).

**D‑042 Transfer Lines** · modal · folio line multi‑select → "Transfer". Target picker: another folio on same reservation, another in‑house reservation (search), company/AR folio. Shows moved subtotal; reason. Writes matched out/in pair with cross‑refs; both folios must be open. Edge: transferring payments (not charges) requires `payment.transfer` and keeps method metadata; cross‑property blocked v1.

**D‑043 Split Folio** · modal · folio actions. Mode radio: by selected lines / by percentage (slider + preview) / preset "room+tax vs incidentals". Creates sibling folio(s) `/2`, `/3` under the reservation, moves lines transactionally. Edge: payments already applied → prompt to allocate payments across splits (table with remainder check = 0 before enable).

**D‑044 Routing Rules** · modal · reservation billing tab. Rule rows: line‑type/charge‑code‑group → target folio (guest/company); add/remove; effective "from now" default; checkbox "re‑route existing matching lines" → generates transfer pairs with preview count. Edge: company credit‑limit breach projected → amber warning with limit math; conflicting rules (same code twice) blocked inline.

**D‑045 Issue Credit Note** · modal · issued invoice page. Scope: full invoice / selected lines (qty adjustable ≤ original); reason enum + note mandatory; preview negative totals + resulting AR effect; on confirm gets own number from shared sequence, PDF rendered, original cross‑referenced both ways. Edge: partial credits cumulative cap = original totals; refund of cash consequence → hand‑off chip to D‑048.

**D‑046 Open Cashier Shift** · modal · payment guard, dashboard. Float amount (denomination helper grid optional), terminal/drawer label, confirm opens `cashier_shifts` row. Edge: user already has open shift on another property → blocked with pointer; property float default prefilled from `ops.default_float_etb`.

**D‑047 Close Cashier Shift** · wizard (3) · shift banner "Close". **S1 Count:** denomination grid (notes 200/100/50/10/5, coins) → counted total. **S2 Reconcile:** expected = float + cash payments − cash refunds − paid‑outs (each row listed); over/short computed with color; variance note required if |Δ| > `ops.cash_variance_tolerance_etb` (default 20). **S3 Confirm:** summary print (shift pack), hand‑over‑to select (optional next cashier), close → shift row sealed, over/short posted to GL bucket + supervisor notification if flagged. Edge: unfinished pending Chapa payments in shift → warning list (non‑blocking, they're not cash); closing blocked if a D‑040 cash dialog is mid‑flight (active payment lock).

**D‑048 Refund** · modal · payment row / folio credit. Source payment context shown (method, date, remaining refundable); amount ≤ remainder; method auto‑matched to source (§19.2); reason enum + note; if amount > `pay.refund_approval_threshold_etb` → submit creates approval task, dialog ends in "pending approval" state with tracker chip. Cash path requires open shift (dispensed from drawer, logged as negative). Edge: provider refund API failure → row enters retry queue, dialog shows error + "will retry automatically"; original payment disputed → blocked until dispute cleared.

**D‑049 Refund Approval** · modal (manager) · approvals inbox / notification deep‑link. Read‑only context pack: guest, folio excerpt, original payment, requested amount, requester note; Approve (executes refund flow) / Reject (note required, requester notified). Edge: approver = requester → blocked (four‑eyes rule); auto‑expire after `pay.refund_approval_ttl_hours` (48) → rejected‑expired with notification.


### 37.6 Rates & inventory (D‑050 – D‑054)

**D‑050 Bulk Rate Edit** · wizard (2) · rate calendar toolbar. **S1 Scope:** date range, days‑of‑week checkboxes, room types multi‑select, rate plans multi‑select. **S2 Change:** mode radio — set absolute price / adjust ± amount / adjust ± % / restrictions only; restriction toggles (min_los value, cta, ctd, stop_sell) each tri‑state (set on / set off / leave); live preview "will modify **N** cells" with a 7‑day sample table before Apply. Applies as season‑exception rows in one txn; audit one summary event + row detail. Edge: N > 5,000 cells → runs as background job with progress toast; overlapping pending job on same scope → blocked; result includes skipped cells (derived plans without override permission) with count + reason.

**D‑051 Rate Plan Wizard** · wizard (4) · Plans "+New" / edit. S1 Identity: code, bilingual name, currency ETB fixed, base vs derived radio; derived → parent plan + offset (± amount | ± %) with sample computation. S2 Scope: room types included, channels visibility (direct/OTA/corporate), meal plan tag (RO/BB/HB/FB — informational + charge‑code link optional). S3 Policies: cancel policy select, deposit rule (none/first_night/pct/flat + value), taxes profile. S4 Seasons: table of date‑band rows per type (add/clone/inline edit) → review + save. Edge: code collision → inline error; deactivating a plan with future reservations → warning list + "existing stays keep their snapshot rates" notice; derived depth limited to 1 (no chains) — validated.

**D‑052 Derived‑Link Change** · modal · derived plan settings. Shows old vs new offset and a recomputed sample week per room type (table diff, red/green deltas); checkbox "I understand future materialized rates will be rebuilt tonight" (or "rebuild now" button → triggers `rate-materializer` for the plan). Edge: parent plan itself derived (blocked by rule above) — defensive message; rebuild collision with running audit → queued after audit.

**D‑053 Restrictions Editor** · popover‑modal · rate‑calendar cell / range select. Per‑cell or range: min_los stepper, CTA/CTD/stop_sell switches with plain‑language explainer line each ("Guests cannot *arrive* on this date"); shows which channels the restriction propagates to (iCal = availability zero only for stop_sell). Edge: conflicting combo (min_los > remaining season length) → warning; clearing restrictions needs same perm as setting (`rate.manage`).

**D‑054 Re‑Rate Existing Reservations** · wizard (2, manager) · after rate edits banner "N future reservations reference changed cells". S1 List affected (conf no, guest, dates, old→new total diff, source — OTA rows excluded with lock icon); select all/none; S2 mode: re‑rate selected now / notify‑only / skip. Executes per‑reservation `rerate` RPC (snapshots preserved in `reservation_daily_rates` history). Edge: checked‑in stays excluded (only future nights re‑ratable via their own detail); guest‑confirmed prices policy note shown (`rate.rerate_requires_notice` flag adds mandatory message send).

### 37.7 Housekeeping & maintenance (D‑055 – D‑059, D‑069 – D‑070)

**D‑055 Bulk HK Assign** · modal · HK board toolbar. Left: unassigned task list (filter floor/type/priority); right: housekeeper roster with current credit load bars; modes: manual drag/checkbox assign · "auto‑balance by credits" (greedy fill respecting `hk.max_credits_per_shift`, preview before apply) · "assign by floor" mapping rows. Confirm writes assignments + notifies each housekeeper (push/in‑app). Edge: housekeeper marked absent today → excluded with note; re‑running auto‑balance after partial manual edits only fills gaps (never reshuffles confirmed rows).

**D‑056 Inspection Checklist** · modal (mobile‑first) · supervisor on `vacant_clean` room. Checklist items from `settings.hk_checklist` (per room type override), each pass/fail + note + photo; overall verdict auto (any fail → fail). Pass → `vacant_inspected`; Fail → back to `vacant_dirty`, defects summary → optional one‑tap "create WO" per failed item (pre‑filled D‑070). Edge: offline flaky connection → answers cached locally, submit retries (§36 standard 9); checklist edited by admin mid‑inspection → completes against opened version.

**D‑057 Room Block (OOO/OOS)** · modal · room context menu, maintenance module, tape chart drag on OOO lane. Kind radio OOO/OOS with plain‑language effect line; room(s) multi‑select; date range; reason enum + note; optional linked WO (search/create). On save, conflict scan: overlapping assigned reservations render a resolver table (each row → relocate action opening a room picker) — Save disabled until zero conflicts or range shrunk. If actor's role requires approval (`mx.ooo_requires_approval`) → saves as *pending* (amber) + manager notification with one‑click approve/reject. Edge: extending an active block re‑runs scan for the delta only; OOO covering tonight with in‑house occupant → hard block "room occupied — move guest first (D‑032)".

**D‑058 Lost & Found** · modal (mobile‑first) · housekeeper room view, HK module. Found item: description, category, photo(s), found‑in room + auto date/finder; storage location select. Claim flow (second mode): match search, claimant identity + ID ref, release signature checkbox, or "dispose after `hk.lf_retention_days` (90)" cron suggestion queue. Edge: item linked to recent guest → one‑tap notify guest (template `lost_item_found`); high‑value flag → manager notification + locked storage location required.

**D‑059 Resolve Discrepancy** · modal · FD discrepancy queue chip. Shows PMS state vs HK reported state, room, reporter, time; outcome radio (forces choice): "HK was right → correct PMS" (executes matching status fix / opens skip‑out flow) · "PMS is right → recheck" (task back to HK with note) · "Guest located — no change" (note) · "Open incident" (skipper: folio → disputed, manager notified, DNR suggestion pre‑filled D‑063). Every outcome audited with both states. Edge: discrepancy auto‑resolves (e.g., checkout happened) → dialog shows "already consistent" close‑only state.

**D‑069 Work‑Order Detail Actions** · modal set · WO page. Contextual per state: **Triage** (priority P1–P4 with SLA due preview, category confirm, assignee pick) · **Hold** (reason enum parts/access/vendor + expected resume date) · **Complete** (work notes required, parts/cost lines optional numeric ETB, photos after) · **Verify** (pass → closed; fail → comment required, back to in_progress) · **Cancel** (reason, blocked once completed). Each is a small focused modal, not one mega‑form. Edge: verifier lacks `mx.close` → button hidden; SLA already breached → banner with breach duration in all states.

**D‑070 Create Work Order** · modal (embeddable, mobile‑first) · anywhere "Report issue", HK checklist fail, room context. Location (room picker or free‑area text), category select, description, photos (camera capture), priority suggestion (default P3; P1 selectable only by supervisor+ — others request P1 with justification note), "room unusable?" toggle → offers OOS/OOO hand‑off chip (D‑057). Edge: duplicate detector (same room + category open WO) → shows existing with "add note instead" path; created from checklist → context auto‑attached.

### 37.8 Guests & privacy (D‑062 – D‑065)

**D‑062 Merge Guests** · wizard (3, `guest.merge`) · dedupe suggestion panel, guest list multi‑select. S1 pick survivor (side‑by‑side cards, stay counts); S2 field‑level conflict picker (radio per differing field, "keep both" for phones/emails → arrays); S3 impact preview (N reservations, folios, notes re‑pointed) → Merge executes single txn, loser tombstoned with redirect row. Edge: both have future reservations same dates → warning (possible real duplicates staying twice — allowed with ack); merged guest has DNR → survivor inherits, highlighted; undo not offered (audit trail only) — copy states this plainly.

**D‑063 Set / Lift DNR** · modal (manager) · guest profile, D‑059 hand‑off. Level radio warn/block with effect explainer; reason enum (misconduct, damage, fraud, unpaid, other) + narrative; evidence attachment optional (perm‑gated visibility); effective immediately. Lift mode requires lifting note + shows original context. Both directions audited + owner notification if `guest.dnr_notify_owner`. Edge: guest currently in‑house + block level → advisory "does not eject current stay; applies to future".

**D‑064 Anonymize Guest** · modal (danger pattern) · guest profile privacy tab. Pre‑check list rendered live: no future reservations ✅/❌, no open balance ✅/❌, no active DNR‑block (must lift first) — any ❌ blocks with deep link. Explains irreversibility; type‑to‑confirm guest surname; on confirm: PII scrubbed to `Guest‑{hash}`, ID files deleted from storage, financial aggregates retained. Edge: legal‑hold flag on tenant (platform‑set) → action disabled with notice.

**D‑065 Export Guest Data** · modal · guest privacy tab. Scope checklist (profile, stays, folios, messages); format JSON + human PDF; generates via Edge `tenant-export` (guest‑scoped mode) → signed URL (24 h) + optional email to guest. Audited as `guest.data_export`. Edge: repeated exports rate‑limited 1/day per guest.

### 37.9 POS (D‑066 – D‑067, D‑080)

**D‑066 Room Post** · modal · POS ticket "Charge to room". Search in‑house by room number or guest name; result card shows guest full name + room **large** (mis‑post prevention), folio balance chip; optional signature capture canvas if `pos.capture_signature`; confirm posts one consolidated folio line (ticket ref) and locks the ticket. Edge: guest on cash‑only flag (`no_post` on reservation, set at check‑in for unguaranteed stays) → blocked with "collect payment" hand‑off; two guests same surname different rooms → both shown, room number required to proceed; checkout in progress on that folio (lock) → retry message.

**D‑067 POS Day Close** · wizard (3) · outlet menu (supervisor). S1 Open‑ticket sweep: list of not‑closed tickets with one‑tap resolve (pay / room‑post / void with reason); cannot advance until zero. S2 Summary: sales by category, by payment method, room‑posts total, voids list (after‑send voids highlighted for ack initials). S3 Confirm close → `pos_day_status` sealed for outlet+date (feeds night‑audit precondition), summary print. Edge: re‑opening a closed POS day requires manager + reason (audited, audit not yet run for that date).

**D‑080 Void Ticket Line** · popover‑modal · ticket line context. Reason enum (error / waste / comp) + note when after‑send; comp requires `pos.comp` and posts zero‑price flag rather than deletion; all voids retained strike‑through on ticket. Edge: line already room‑posted (ticket locked) → correction must go through folio adjust flow instead — explanatory copy with deep link.


### 37.10 Tenant administration (D‑060 – D‑061, D‑068, D‑071 – D‑072, D‑074, D‑079)

**D‑060 Invite User** · modal · Settings → Team "+Invite". Email (uniqueness across tenant checked live), display name, property assignments (multi, or "all current & future" toggle for tenant‑wide roles), role(s) per property via chips, personal note in invite email; plan seat‑limit check (`limits.users`) before send → D‑006 on breach. Sends Supabase invite (7‑day expiry) + `invitations` row. Edge: email belongs to an existing *revoked* member → "reactivate instead" path; inviting `owner` role requires current owner + type‑to‑confirm; resend throttled 1/10 min.

**D‑061 Accept Invite** · full‑page wizard (public route) · email link. S1 token validation (expired/revoked → friendly dead‑end with "ask your admin to resend"); S2 set password (policy meter) + display name + locale preference (en/am); S3 MFA enrollment if any granted role requires it (embeds D‑026, not skippable); lands on property dashboard with 4‑step first‑run coach marks. Edge: user already has an Engida account on another tenant (same email) → sign‑in variant that *links* new membership instead of creating auth user.

**D‑068 Risky Setting Confirmation** · alert · saving any setting flagged `risky:true` in registry §29 (tax rates, vat_inclusive, payment methods off, currency lock, session policy). Shows old → new value diff, effect line ("applies to **future** postings only — issued documents never change"), affected‑scope estimate where computable ("~N future reservations reference this plan"); type field for change reason (goes to audit). Edge: two risky settings changed in one save → single dialog with stacked diffs; owner‑only settings render read‑only for others (no dialog at all).

**D‑071 Upload Transfer Proof** · modal · Settings → Billing, `saas_invoice` row "Pay". Invoice summary (number, period, amount ETB, platform bank accounts list with copy buttons); upload proof image/PDF (≤10 MB → `saas-proofs` bucket), transfer reference, paid date; submit → invoice `proof_submitted`, platform approval queue notified. Edge: resubmission after rejection shows rejection note prominently; overpayment/partial noted in amount field with variance flag for platform reviewer.

**D‑072 Template Editor** · modal (large) · Settings → Notifications, template row. Left editor (subject + body per channel tab email/SMS/in‑app), right live preview with sample payload; variable palette (chips insert `{{guest_name}}` etc. at cursor, unknown variables lint red); per‑locale tabs en/am with "copy from en" helper; SMS segment counter (GSM7 vs UCS‑2 auto‑detected — Amharic 70/67 chars rule) with cost hint; Test‑send to self button; system templates are clone‑on‑edit with "Reset to default" action. Edge: removing a *required* variable (e.g., `{{otp}}` in OTP template) → save blocked; saving mid test‑send race is fine (test uses draft payload).

**D‑074 Schedule Report** · modal · any report toolbar "Schedule" (Growth+). Cadence (daily 07:00 / weekly Mon / monthly 1st — property TZ), recipients (member picker + free emails), format CSV/PDF/both, parameter freeze snapshot shown (date‑window token like "yesterday", "last EC month"); list of existing schedules with pause/delete. Edge: recipient loses membership → schedule row flags + skips them; plan downgrade below Growth → schedules paused with banner, not deleted.

**D‑079 Edit Member Roles** · modal · Team member row. Per‑property role chips editor (same component as D‑060), effective‑permission preview accordion ("this grants: …" rendered from §6.2 registry), deactivate toggle (blocks login, keeps history), "force re‑login" action (bumps token version → claims refresh). Guard rails: cannot remove the last `owner`; self‑demotion warns; changes apply on next token refresh ≤ 60 s (or forced). Edge: member has open cashier shift → role removal warns "close shift first" (blocking for cashier‑perm removal).

### 37.11 Platform console (D‑073, D‑075 – D‑077)

**D‑073 Impersonation Start** · wizard (2, platform_admin) · tenant detail "Support session". S1 target: property + role to assume (default manager) + **read‑only toggle default ON**; S2 justification: reason enum (support ticket / billing / incident / onboarding) + ticket ref mandatory + duration select (15/30/60 min max). Confirm mints time‑boxed token (Edge `mint-impersonation`) and opens the tenant app in a new tab with the persistent red banner ("Support session as {tenant} — {mm:ss} — [End now]"). All actions audit with `impersonated_by`; owner summary notification per flag. Edge: second concurrent impersonation of the same tenant → blocked with active‑session holder shown; write attempted in read‑only → D‑004 variant naming the RO session.

**D‑075 Tenant Provisioning** · wizard (5, platform_admin) · Tenants "+New". S1 Organization: legal name, TIN, contact owner (name/email/phone), locale default. S2 Plan & term: plan select, trial toggle (`saas.trial_days` prefill), price override field (discounts, audited). S3 First property: name, city/region, rooms count estimate, check‑in/out times, TZ (Africa/Addis_Ababa default). S4 Seed options: checkbox set — standard room types pack, charge‑codes pack (ET VAT profiles), HK checklist pack, demo data OFF default. S5 Review → `provision_tenant` RPC (creates tenant, property, owner invite, defaults, flags) → success screen with owner‑invite status + "copy onboarding checklist" for CS. Edge: TIN duplicate across tenants → warn (legit for multi‑brand owners, ack to continue); RPC is idempotent on org+email pair (retry safe); invite email bounce later surfaces in tenant health dot.

**D‑076a Suspend Tenant** · modal (danger) · tenant danger zone. Reason enum (non‑payment / abuse / owner request / legal) + note; effect summary bullet list (read‑only mode, humane checkout window §28.3, staff banner text preview); optional scheduled date vs now. Confirm → status `suspended`, tenant‑wide banner + owner notification. Edge: suspension during that tenant's running night audit → deferred until audit completes (queued, shown).

**D‑076b Purge Tenant** · modal (maximum danger) · only visible when `cancelled` ≥ `saas.purge_after_days`. Checklist gates rendered live: final export generated + downloaded ✅ (button runs §32.3 export inline), no legal hold ✅; type the exact tenant name; second checkbox "I understand this is irreversible"; confirm → `purge_scheduled` (+72 h cooling) with countdown shown on tenant card and a cancel‑purge action until execution. Edge: any new payment/proof arriving during cooling window auto‑cancels purge + alerts platform.

**D‑077 Platform Announcement** · modal · console Announcements. Audience (all tenants / plan filter / tenant multi‑select), severity (info/maintenance/critical → banner style), title + body per locale, schedule window (start/end), channels (in‑app banner always; email optional). Preview pane per severity. Critical announcements require second platform_admin approval (four‑eyes) before send. Edge: overlapping active critical banners → only newest shows, others queued (listed).

### 37.12 Night audit (D‑078)

**D‑078 Night Audit Wizard** · full‑screen wizard (6, `audit.run`) · Audit module "Run audit for {business_date}". Steps per §20.2 with a fixed left rail progress list; each step card shows its checklist with live pass/fail rows and inline resolve links; **Step 5 rollover** requires typing `ADVANCE` verbatim. Blocking preconditions (§20.1) render as the wizard's step 0 gate: open cashier shifts (deep links), open POS days, in‑flight payment dialogs, pending audit from a prior date. Failure mid‑run: banner "resumable — completed steps are idempotent", audit row `failed_at_step` stored; re‑entry resumes at failed step; 06:00 local unresolved → escalation notification chain (manager → owner). Completion: reports pack generated (links list), `business_date` advanced, dashboard KPI snapshot frozen into `v_daily_stats` materialization. Edge: two auditors racing → advisory lock makes second a read‑only observer of live progress; clock skew warning if server date vs property TZ midnight mismatch > 2 h.

### 37.13 Channels (D‑081 – D‑082)

**D‑081 iCal Channel Setup** · wizard (3) · Channels "+Connect iCal". S1 platform pick (Booking.com / Airbnb / generic) with per‑platform help notes; S2 per‑room‑type mapping rows: import URL (validated by test fetch showing parsed event count) + export URL generated (copy button, secret token embedded, regenerate action); S3 sync options: cadence display (10‑min cron, fixed), overlap policy = block‑and‑queue (fixed, explainer), enable. Edge: import URL returns non‑iCal → inline parse error with first bytes shown; export URL regeneration invalidates old (warning: update on the OTA side).

**D‑082 Sync Conflict Resolution** · modal · Channels conflict queue row. Side‑by‑side: OTA event (dates, summary, UID) vs conflicting PMS state (reservation/OOO); actions: accept OTA (relocate/adjust local via guided sub‑steps) / reject (keep local; note that OTA side must be amended — copy channel ref) / merge notes only. Every resolution audited; queue badge counts in nav. Edge: conflict auto‑resolved by later sync → row auto‑closes with "superseded" tag; repeated conflicts same room+range (flapping) → suggests stop‑sell on that cell (one‑tap D‑053).

---

**Dialog coverage check:** D‑001–D‑009 global · D‑010–D‑019 reservations/groups · D‑026–D‑028 auth · D‑030–D‑039 front desk · D‑040–D‑049 money · D‑050–D‑054 rates · D‑055–D‑059 + D‑069–D‑070 HK/maintenance · D‑060–D‑061, D‑068, D‑071–D‑072, D‑074, D‑079 tenant admin · D‑062–D‑065 guests/privacy · D‑066–D‑067, D‑080 POS · D‑073, D‑075–D‑077 platform · D‑078 audit · D‑081–D‑082 channels. Unused numbers (D‑020–D‑025, D‑029) are **reserved bands** for v1.x additions within their sections. Every dialog referenced anywhere in Parts B–E resolves to an entry above.


---

# PART G — CROSS‑CUTTING CONCERNS

## 38. Error‑handling framework

### 38.1 Error envelope (every RPC & Edge Function)
```json
{ "error": { "code": "BIZ_ROOM_UNAVAILABLE", "message": "Room 204 is no longer available for these dates.",
  "details": { "room_id": "…", "conflict_nights": ["2026-07-22"] },
  "correlation_id": "01J…ULID", "retryable": false } }
```
Rules: `code` is stable machine taxonomy; `message` is human, localized server‑side by `Accept-Language`; `details` is safe structured context only (never SQL, never stack); `correlation_id` (ULID) is generated at the edge, propagated through Postgres via `set_config('app.correlation_id', …)`, written into `audit_log` and Sentry — one ID stitches client toast → RPC → audit row → Sentry event.

### 38.2 Code taxonomy
| Prefix | Meaning | Examples |
|---|---|---|
| `AUTH_` | Authentication | `AUTH_INVALID_CREDENTIALS`, `AUTH_MFA_REQUIRED`, `AUTH_SESSION_EXPIRED` |
| `AUTHZ_` | Authorization | `AUTHZ_DENIED` (perm key in details), `AUTHZ_TENANT_MISMATCH`, `AUTHZ_READONLY_IMPERSONATION` |
| `VAL_` | Validation (shape/range) | `VAL_SCHEMA` (zod issues array in details), `VAL_DATE_RANGE`, `VAL_AMOUNT_NEGATIVE` |
| `BIZ_` | Business rule | `BIZ_ROOM_UNAVAILABLE`, `BIZ_FOLIO_NOT_ZERO`, `BIZ_AUDIT_IN_PROGRESS`, `BIZ_SHIFT_REQUIRED`, `BIZ_HOLD_EXPIRED`, `BIZ_PLAN_LIMIT`, `BIZ_TENANT_READONLY`, `BIZ_DNR_BLOCK`, `BIZ_INVOICE_IMMUTABLE`, `BIZ_REFUND_EXCEEDS`, `BIZ_CONFLICT_STALE` (=P0409 surfaced) |
| `PAY_` | Provider/payment | `PAY_PROVIDER_DOWN`, `PAY_WEBHOOK_SIG`, `PAY_REFUND_FAILED` |
| `SYS_` | Infra/unknown | `SYS_UNAVAILABLE`, `SYS_TIMEOUT`, `SYS_RATE_LIMITED`, `SYS_UNKNOWN` |

Postgres mapping: RPCs raise `exception using errcode='P0400'..` families with the code in `MESSAGE`/`DETAIL` json; the thin API layer translates SQLSTATE → envelope (`23P01` exclusion → `BIZ_ROOM_UNAVAILABLE`; `23505` unique → context‑specific `BIZ_*`; custom `P0409` → `BIZ_CONFLICT_STALE`; `P0403` → `AUTHZ_DENIED`).

### 38.3 Client handling matrix
| Class | Surface | Behavior |
|---|---|---|
| `VAL_` | Inline field errors | Map zod issue paths to RHF `setError`; never a toast |
| `AUTHZ_DENIED` | D‑004 dialog | Names the missing permission; "request access" action |
| `BIZ_*` expected (availability, balance, limits) | Contextual panel inside the open dialog/screen | Specific recovery CTAs (defined per dialog in §37) |
| `BIZ_CONFLICT_STALE` | D‑005 | Reload/diff/overwrite pattern |
| `BIZ_TENANT_READONLY` | Blocking banner + toast | Copy varies by saas status (§28.3) |
| `PAY_*` | In‑dialog status area | Retry with new idempotency key only where safe (query ops); payment submits **reuse** the same key |
| `SYS_*` | Toast + "Details" (D‑007) | Auto‑retry policy below |

Retry: TanStack Query — reads retry 3× exponential (1s/2s/4s, jitter) on `SYS_`/network only; mutations never auto‑retry except idempotent‑keyed submits after network drop, which re‑send the identical payload (standard 9 §36). Global handlers: `onError` → taxonomy switch; `401` → single silent refresh attempt → D‑003; Realtime disconnect → amber "reconnecting" pill, queries refetch on reconnect.

### 38.4 Failure containment
Every dialog defines its failure states in §37 — the framework guarantees: no double‑submit (buttons disable on in‑flight + idempotency), no silent partial success (RPCs are single‑txn), no data loss on transient failure (dirty forms survive via in‑memory retry, D‑003 preserves state), and no dead ends (every error surface offers a next step).

## 39. Validation standards
Single source: `packages/shared-types/src/schemas/*` — Zod schemas exported per entity + per RPC input; client forms consume them via `zodResolver`; server Edge Functions re‑parse with the same schema; Postgres constraints (§11) are the final wall — three layers, one definition. Conventions: trim + NFC‑normalize all strings; Ethiopic digits (፩…) normalized to ASCII in numeric inputs; phone → E.164 with `+251` default region; money `z.number().multipleOf(0.01).nonnegative()` (ETB, no FX); dates ISO `yyyy-MM-dd` (Gregorian canonical, EC only at render); IDs `z.string().uuid()`. Cross‑field rules live in `.superRefine` (departure > arrival; children ≤ adults×4; refund ≤ remainder). Error copy: every schema issue has an i18n key (`val.departure_after_arrival`) — raw zod messages never shown. Server‑only invariants (availability, balance, limits) are **not** duplicated in Zod — they return `BIZ_*` and render per §38.3.

## 40. i18n, Amharic & the Ethiopian calendar
- **Framework:** `i18next` + ICU messages; locales `en`, `am`; per‑user preference (profile) → falls back to tenant default → `en`. All UI strings keyed (`frontdesk.checkin.title`); missing‑key CI check fails the build; Amharic reviewed by a human before each release (never machine‑only).
- **Fonts/layout:** Noto Sans Ethiopic loaded with `unicode-range` subsetting; both locales LTR; line‑height 1.6 for Ethiopic; inputs accept Ethiopic freely (names, notes) — search normalizes (§ D‑009).
- **Ethiopian calendar:** conversion module `packages/shared-types/src/ethiopic.ts` — pure functions `gcToEc`, `ecToGc`, `ecMonthDays(y,m)` (13 months; Pagume = 5 days, 6 when `(ecYear % 4) === 3`), EC new year = Gregorian Sep 11 (Sep 12 preceding leap). Ships with a golden‑vector test file (200 known pairs incl. Pagume 6 cases 2011/2015/2019 EC and year boundaries) — **no external date lib for EC**. Display component `<StayDate/>` renders per `calendar.dual_display` ("Tir 12, 2018 EC · 20 Jan 2026"); EC month names bilingual (መስከረም/Meskerem …). Operational truth stays Gregorian everywhere in the DB (D‑009 decision) — EC appears only in rendering, report grouping (`calendar.report_grouping = ec_month` regroups by EC boundaries), and date pickers (toggle tab, both calendars select the same underlying GC date).
- **Numbers/money:** `Intl.NumberFormat('en-ET')` grouping; ETB symbol placement "ETB 1,234.56" (locale‑stable, never "$"); amount‑in‑words generator for invoices in both languages (tested to 999,999,999.99).
- **Time:** property TZ `Africa/Addis_Ababa` (no DST); business_date is the operational day key (§20); UI shows clock time 24 h default with a 12 h setting.

## 41. Ethiopia compliance pack

### 41.1 Scope statement
Engida v1 implements VAT‑registered hotel invoicing conventions and keeps a **fiscal adapter seam** for ERCA e‑invoice/fiscal‑printer integration (P2). Items marked §49 require confirmation against current law at go‑live — the system defaults are configurable, not hard‑coded.

### 41.2 Charge computation order (fixed, tested)
For a base amount `B` with service charge `s` (default 0.10) and VAT `v` (default 0.15), exclusive pricing (default): `service = B × s`; `vat = (B + service) × v` (VAT on base+service — the hospitality convention); `total = B + service + vat`. Inclusive mode (`billing.vat_inclusive=true`): back‑compute `B = total ÷ ((1+s)(1+v))`, then derive lines. Every folio line stores `base_amount, service_amount, vat_amount, total_amount` — never recomputed after posting. Tourism levy line inserts between service and VAT when `billing.levy_rate > 0` (§49). Rounding: half‑up to 0.01 per line; invoice totals = Σ lines (no re‑rounding drift — property tested).

### 41.3 Invoice content requirements
Header: property legal name, TIN, address, invoice no. (gap‑free per property §18.2), issue date (GC, EC shown), guest/company name (+TIN when provided — required for corporate claiming input VAT). Lines: description (bilingual where template exists), qty, unit, base, service, VAT, total. Footer: totals block, VAT summary by rate, amount‑in‑words (en+am), payment status, `FS No.` placeholder populated by fiscal adapter when active. Credit notes mirror with negatives + original ref. Proforma = `PF‑` prefix, out of fiscal sequence, watermark.

### 41.4 Payments & banking reality
Cash‑heavy operation is first‑class (drawer/shift discipline §14.4); bank transfer with reference capture is the corporate norm; Chapa covers cards + wallets (incl. Telebirr via Chapa) with direct Telebirr adapter optional; settlement recon report (payments vs provider payout export CSV import) ships P2. No FX ledger — foreign currency handled outside system per NBE rules (§49), note fields provided.

### 41.5 Data protection
Ethiopia's Personal Data Protection Proclamation (1321/2024) principles applied: purpose‑bound collection (registration requirement), guest export (D‑065), anonymize (D‑064), retention schedule (§33), ID images in a locked bucket with perm‑gated, audited access, breach‑notification runbook (§30.4).

## 42. Performance & resilience budgets
| Surface | Budget (p95, Addis 4G) | Technique |
|---|---|---|
| First load (dashboard) | ≤ 3.5 s LCP; JS ≤ 350 KB gz initial | Route‑level code splitting (TanStack Router lazy), font subsetting, no moment‑style libs |
| Route change | ≤ 400 ms | Prefetch on hover/viewport; loader + cache |
| Tape chart 100 rooms × 30 d | ≤ 1 s render, 60 fps scroll | Virtualized grid, single availability query (`v_availability` range), memoized cells |
| Search (guests/res) | ≤ 500 ms | `pg_trgm` indexes, debounce 250 ms, server limit 20 |
| RPC writes | ≤ 800 ms | Single‑txn RPCs, partial indexes on hot predicates (§11) |
| Night audit 100 rooms | ≤ 3 min end‑to‑end | Set‑based posting (one INSERT…SELECT per step), advisory lock |
| Realtime fan‑out | ≤ 2 s to boards | Channel per property, invalidation payloads only (no row data) |

Resilience: Postgres is the only stateful truth (Supabase HA); Edge Functions stateless + idempotent; webhook consumers tolerate replays; crons overlap‑guarded by advisory locks; browser offline → banner + queued idempotent submits (§36.9); graceful degradation order documented (Realtime → polling 30 s; charts → tables; PDF render → HTML print).

## 43. Security requirements (OWASP ASVS‑lite mapping)
| OWASP Top 10 (2021) | Engida control |
|---|---|
| A01 Broken access control | RLS enabled+forced on 100 % of tables (pgTAP CI gate §46); money/state tables RPC‑only (no direct grants); perm checks inside every RPC (`app.has_perm`); object storage path policies §12; IDOR impossible by construction (tenant_id from JWT, never from client) |
| A02 Cryptographic failures | TLS everywhere; at‑rest via Supabase; no card data ever touches Engida (Chapa hosted checkout); secrets in platform vaults only (§47); signed URLs short‑TTL |
| A03 Injection | No string‑built SQL (RPCs use parameters; supabase‑js builders); `dangerouslySetInnerHTML` banned by ESLint rule + CI grep; template rendering escapes by default (notification editor variables are text‑substitution, not eval) |
| A04 Insecure design | This document: state machines server‑side, four‑eyes on refunds/critical announcements, type‑to‑confirm on destructive ops, humane read‑only mode |
| A05 Security misconfiguration | Env matrix §47 reviewed; Supabase: `anon` key scoped by RLS only, service_role never in client, JWT expiry 60 min, email confirmations on; security headers (CSP default‑src 'self' + Supabase/Chapa origins, HSTS, frame‑ancestors none) via Vercel config |
| A06 Vulnerable components | Renovate weekly; `npm audit` CI gate (fail on high); lockfile committed |
| A07 Auth failures | §5 policy: rate‑limited login, MFA for privileged roles, session idle timeout, global sign‑out on password change, invite tokens single‑use 7 d |
| A08 Integrity failures | Webhooks HMAC‑verified + idempotent (§19.3); CI provenance (locked deps); migrations forward‑only with checksums |
| A09 Logging failures | §31 audit trail insert‑only + correlation IDs; auth events logged; Sentry scrubs PII fields list |
| A10 SSRF | Edge Functions fetch only allow‑listed hosts (Chapa, Telebirr, Resend, SMS gateway, iCal URLs validated http(s) + public‑IP check) |

Additions: brute‑force lockouts (§5), impersonation controls (§27.4), quarterly access review report (members × perms per tenant, one‑click), pen‑test before GA, dependency SBOM export.

## 44. Accessibility (WCAG 2.1 AA)
Radix/shadcn primitives give focus management, roles, and escape handling — the spec adds: full keyboard paths for the tape chart (arrow‑key cell nav + Enter opens D‑010/D‑032); visible focus rings (2 px gold on navy — 4.6:1); color never the sole signal (status pills carry text/icons; over/short shows sign); contrast tokens audited (§34 palette all ≥ 4.5:1 for text); form errors announced via `aria-live="polite"` + programmatic focus to first error; dialogs: `aria-modal`, labelled by title, focus trap + restore (§36.1); tables get captions + scope headers; Amharic screen‑reader sanity pass (NVDA + Ethiopic) each release; motion‑reduce media query honored (no essential animation); touch targets ≥ 44 px on HK/POS mobile surfaces; print styles for reg cards/reports maintain contrast.


---

# PART H — DELIVERY

## 45. Repository structure (monorepo, pnpm)
```
engida/
├─ apps/web/                      # React 18 + Vite + TS (the PMS app + platform console behind role gate)
│  ├─ src/app/                    # TanStack Router file routes (routes mirror §35 nav map)
│  ├─ src/features/<module>/      # api/ (query+mutation hooks) · components/ · dialogs/ (Dxxx files) · schemas re-exports
│  ├─ src/components/ui/          # shadcn/ui (generated, unmodified) + engida/ wrappers (<Money/>, <StayDate/>, <StatusPill/>)
│  ├─ src/lib/                    # supabase client, error mapper (§38), i18n init, idempotency, realtime bus
│  └─ src/locales/{en,am}/*.json
├─ packages/shared-types/         # zod schemas, generated supabase types, ethiopic.ts, permissions.ts (registry §6.2 as code), flags.ts (§29)
├─ supabase/
│  ├─ migrations/                 # 0001_extensions.sql … NNNN (forward-only; naming: NNNN_<scope>_<desc>.sql)
│  ├─ functions/<name>/index.ts   # registry Appendix B (deno)
│  ├─ seed/                       # seed.sql (reference data: et_admin_divisions, charge-code packs, templates) + demo/ (Appendix C)
│  └─ tests/                      # pgTAP: rls_coverage.sql, state_machines.sql, money_invariants.sql, ethiopic_vectors.sql
├─ docs/                          # this blueprint + ADRs (adr/NNNN-*.md) + runbooks (§32.4, §30.4)
├─ .github/workflows/ci.yml, deploy.yml
└─ .env.example                   # every var from §47 with comments, no values
```
Rules: features never import each other's internals (shared via packages or `lib`); dialogs live beside their feature and register in a `dialogRegistry` (id → lazy component) so §37 IDs are literal code artifacts; `permissions.ts` and `flags.ts` are the **single sources** — UI gates, RPC seeds, and docs tables are generated from them (drift check in CI).

## 46. CI/CD & migration workflow
**Pipeline (GitHub Actions, on PR):** install (pnpm, frozen lockfile) → lint (eslint incl. custom rules: no `dangerouslySetInnerHTML`, no `service_role`, no raw date libs for EC) → typecheck → unit tests (vitest: ethiopic vectors, money math §41.2, schema round-trips) → build → **db job:** spin ephemeral Supabase (CLI) → apply all migrations from zero → run pgTAP suite: `rls_coverage` asserts every table in `public` has RLS **enabled AND forced** and at least one policy or a `revoke-all + rpc-only` marker comment (100 % or fail); state-machine tests exercise every §13/§16/§17/§18 transition legal + illegal; exclusion-constraint test attempts a double-assign and expects `23P01` → e2e smoke (Playwright: login → walk-in → payment → checkout → audit on seeded db).
**Migrations:** forward-only, one logical change per file; every migration paired with a `-- verify:` block (assertions run in CI); no `down` scripts (restore = PITR); RLS policies live in dedicated `NNNN_rls_*.sql` files so coverage diffs are reviewable; migration touching money tables requires a second reviewer (CODEOWNERS).
**Deploy:** merge to `main` → auto deploy **staging** (Vercel preview promoted + `supabase db push` to engida-staging + functions deploy) → smoke suite runs against staging → manual approval gate → **prod** deploy window (default 22:00 EAT, never during 00:00–06:00 audit band); prod migration runs with `statement_timeout=5min`, wrapped in advisory lock; rollback = redeploy previous web build + PITR only for data incidents (runbook §32.4).
**Lovable workflow:** Lovable generates UI against staging Supabase; exported code lands as PRs into `apps/web` and passes the same pipeline — Lovable is a producer, never a deploy path to prod.

## 47. Deployment configurations
| Concern | dev | staging | prod |
|---|---|---|---|
| Supabase project | engida-dev | engida-staging | engida-prod |
| Web host | Vercel preview URLs | staging.engida.et | app.engida.et |
| Auth redirect/allowed URLs | localhost:5173 + previews | staging domain | app domain only |
| JWT expiry / refresh | 60 min / 30 d | same | same |
| Email | Resend sandbox (test to team) | Resend, `staging-notify@` | Resend prod domain, DKIM/SPF/DMARC verified |
| SMS | mock adapter (logs) | gateway sandbox | gateway prod, registered sender ID (§49) |
| Chapa/Telebirr | test keys, webhook → dev tunnel | test keys | live keys |
| Backups | PITR only | PITR + nightly dump | PITR (7 d) + nightly dump + R2 mirror + weekly verify-restore |
| Sentry env tag | dev (sampled 10 %) | staging (100 %) | prod (100 % errors, 10 % traces) |
| Cron schedules | manual trigger only | real, offset +5 min | real (Appendix B times) |
| Flags default | all modules on, limits high | prod-like | per plan §29 |

**Environment variables (complete, `.env.example`):** `VITE_SUPABASE_URL`, `VITE_SUPABASE_ANON_KEY`, `VITE_APP_ENV`, `VITE_SENTRY_DSN` — client. Functions secrets (per project via `supabase secrets set`): `RESEND_API_KEY`, `SMS_GATEWAY_URL`, `SMS_GATEWAY_KEY`, `CHAPA_SECRET_KEY`, `CHAPA_WEBHOOK_SECRET`, `TELEBIRR_APP_ID`, `TELEBIRR_APP_KEY`, `TELEBIRR_PUBLIC_KEY`, `R2_ACCOUNT_ID`, `R2_ACCESS_KEY_ID`, `R2_SECRET_ACCESS_KEY`, `R2_BUCKET_BACKUPS`, `PLATFORM_ALERT_EMAIL`, `IMPERSONATION_SIGNING_KEY`. Never in client bundle: anything without `VITE_`; CI secret-scan (gitleaks) blocks accidental commits — the .env-in-repo failure mode from prior audits is a hard CI gate here.

## 48. Phased roadmap
| Phase | Weeks | Scope (references) | Exit criteria |
|---|---|---|---|
| **P1 Core PMS** | 1–8 | Auth/roles (§5–8), schema+RLS (§9–12), reservations (§13), front desk (§14), rooms/rates base+seasons (§15), folio/payments cash+transfer (§18–19), night audit (§20), HK core (§16), settings/flags (§29), dialogs: global, D‑010–015, D‑030–041, D‑046–047, D‑078 | One pilot hotel live in Harar; audit runs 14 consecutive nights clean; pgTAP 100 % RLS |
| **P2 Money+** | 9–12 | Chapa/Telebirr (§19.3), invoicing PDF + credit notes (§18.2), refunds+approvals, POS (§21), reports pack (§25), notifications (§26), remaining FD dialogs | Card payment E2E in prod; POS day close feeds audit |
| **P3 Scale ops** | 13–16 | Maintenance (§17), groups (§23), guest CRM full (§22), rate restrictions/derived (§15), scheduled reports, HK mobile polish | Second property onboarded on same tenant |
| **P4 Platform** | 17–20 | Super‑admin console (§27), SaaS billing+dunning (§28), impersonation, backups automation (§32), monitoring (§30), announcements | Self‑serve tenant provisioning; dunning cycle tested end‑to‑end |
| **P5 Connect** | 21–24 | iCal channels (§24), tenant export, fiscal adapter spike (§41), guest portal deposit link, CM API design | 1 OTA connected at pilot; §49 items resolved or formally deferred |

Team assumption: 1–2 devs + Lovable/Claude Code acceleration; each phase ends with a staging → prod promotion and a written retro ADR.

## 49. Go‑live checklist & ⚠ runtime confirmations
**Go‑live (per tenant):** owner MFA enrolled · property times/TZ set · room types+rooms loaded (counts match physical) · rate plans+seasons entered and spot‑checked · charge codes + tax profiles verified against a real receipt · cancel/deposit policies written · templates reviewed in en+am · bank accounts entered · cashier floats set · staff invited with least‑privilege roles · HK checklist confirmed · **parallel run:** 3 nights running Engida beside the old process, audit packs compared line‑by‑line · sign‑off recorded in tenant notes.
**⚠ Runtime confirmations (verify against current Ethiopian law/providers at deployment — defaults are placeholders, each maps to a flag):**
1. VAT rate & hotel service‑charge treatment (`billing.vat_rate`, `billing.service_charge_rate`, computation order §41.2) — confirm with the property's accountant/ERCA guidance.
2. Tourism levy applicability & rate for the property class (`billing.levy_rate`).
3. Chapa webhook signature scheme & header names (verify against live Chapa docs before enabling; test with `chapa-webhook` staging).
4. Telebirr direct‑integration API contract (if not via Chapa) — auth flow, notify URL spec.
5. NBE rules for foreign‑guest payment/foreign currency handling — v1 stance (outside system) validated.
6. ERCA invoice/fiscal‑printer requirements for the pilot property's registration category — decides fiscal‑adapter priority.
7. SMS sender‑ID registration per tenant with the chosen Ethiopian gateway (lead time weeks — start early); Amharic delivery quality tested on Ethio Telecom + Safaricom ET.
8. Data‑retention years for financial records (`retention.financial_years`, default 10) confirmed with accountant.

## 50. Acceptance criteria (per module, testable)
Format: every criterion is a Playwright/pgTAP test id.
- **Auth/RBAC:** each of the ~45 permission keys in §6.2 has a positive test (holder succeeds) and a negative test (non‑holder gets `AUTHZ_DENIED`) — generated from `permissions.ts`; RLS coverage 100 %; cross‑tenant read attempt returns zero rows (not error) for every table.
- **Reservations:** every transition row in §13.2 has legal+illegal tests; double‑assign attempt → `23P01`; hold expires at TTL (clock‑advanced test); overbook beyond allowance blocked.
- **Front desk:** all 8 guards G1–G8 individually forced and verified; checkout with balance blocked without perm, AR path with perm; walk‑in creates+checks‑in atomically (kill mid‑RPC leaves nothing).
- **Money:** §41.2 math property‑tested (1,000 random amounts, both modes, drift = 0); void same‑day vs post‑audit adjust enforced by date; invoice numbers gap‑free under 50 concurrent issuances; refund > threshold requires approval; shift close over/short math matches payments table.
- **Night audit:** rerun of any completed step changes zero rows (idempotency); audit blocked by open shift/POS day; business_date advances exactly +1; failure at step 3 resumes at 3.
- **HK/Maintenance:** every §16/§17 transition tested; OOO overlapping a reservation cannot save; pending OOO doesn't affect availability.
- **POS:** posted ticket immutable; day close blocks audit until sealed.
- **SaaS:** dunning day 0/3/7 emails fire (clock tests); suspension → read‑only blocks all mutation RPCs except checkout+payment for 7 days; purge respects cooling window and cancels on payment.
- **i18n/EC:** 200 golden EC vectors pass; every user‑visible string resolves in `am` (missing‑key report empty); SMS segmentation for Amharic sample = expected counts.
- **Dialogs:** for each D‑xxx, at least one e2e covering its primary path and its first listed edge case (§37 is the test inventory).
- **Ops:** backup‑verify restore test green weekly; synthetic `/health` alert fires on induced failure; correlation_id traceable client→audit→Sentry in one drill.

---

# APPENDICES

## Appendix A — Glossary
| Term | Meaning in Engida |
|---|---|
| **Tenant** | A hotel business (the SaaS customer). Owns one or more properties. Isolation unit for RLS (`tenant_id`). |
| **Property** | A single physical hotel. Owns rooms, its own `business_date`, sequences, cashier shifts, and settings. |
| **Business date** | The operational day for a property, advanced only by Night Audit. All nightly posting keys off it, not the wall clock. |
| **Folio** | A guest/company account for one stay (or AR relationship) accumulating charges and payments; states open → settled → closed. |
| **Folio line** | An immutable posting row: base/service/VAT/total split stored at post time. Corrections are voids (same‑day) or adjustments (post‑audit), never edits. |
| **Rate plan** | A priced product (base or derived) scoped to room types/channels with policies; materialized into daily rates. |
| **Season / exception** | Date‑banded price overrides for a plan+type; single‑day inline edits create one‑day exceptions. |
| **Restriction** | Sell control on a rate cell: min_los, CTA (closed‑to‑arrival), CTD (closed‑to‑departure), stop_sell. |
| **Hold** | A time‑boxed unconfirmed reservation (TTL `res.hold_ttl_minutes`); expires via cron. |
| **Overbook allowance** | Manager‑set extra sellable count per date beyond physical inventory; guarded acknowledgment (D‑015). |
| **OOO / OOS** | Out‑of‑Order (removed from availability + occupancy denominator) / Out‑of‑Service (still sellable, cosmetic flag). |
| **Work order (WO)** | A maintenance task with priority‑driven SLA and its own state machine. |
| **Discrepancy** | Mismatch between PMS room state and housekeeper‑reported physical state (sleeper/skipper). |
| **Night Audit** | The nightly close procedure: posts room+tax, handles no‑shows, seeds HK, rolls the business_date, emits the reports pack. |
| **Cashier shift** | A cash‑accountability window per user with float, reconciled on close (over/short to a GL bucket). |
| **DNR** | "Do Not Rent" flag on a guest (warn or block level) checked at booking and check‑in. |
| **Impersonation** | Time‑boxed, audited platform_admin session into a tenant (read‑only by default) with a persistent red banner. |
| **Read‑only (humane) mode** | The state a past‑due/suspended tenant enters where staff can still check out and take payment for a grace window, but not create new business. |
| **Correlation ID** | A ULID minted at the edge that threads a single action across client → RPC → audit_log → Sentry. |
| **RPC (state‑transition)** | A Postgres `security definer` function that is the *only* legal way to change money/state; enforces perms, guards, and single‑txn atomicity. |
| **Materialized rate** | A concrete `reservation_daily_rates`/rate‑cache row produced from plan+season+restriction resolution, snapshotted onto reservations so later plan edits never rewrite guest‑quoted prices. |
| **EC / GC** | Ethiopian Calendar / Gregorian Calendar. GC is operational truth in the DB; EC is a display/report‑grouping layer. |
| **ETB** | Ethiopian Birr — the only ledger currency; UI renders "ETB 1,234.56", never "$". |
| **Service charge / VAT / levy** | Hospitality charge stack computed in fixed order (§41.2); rates are configurable flags pending §49 confirmation. |
| **Fiscal adapter** | The P2 seam for ERCA e‑invoice / fiscal‑printer registration returning an `FS No.` onto invoices. |
| **Idempotency key** | A client‑generated key on mutating submits so retries (network drops, double‑clicks, webhook replays) never double‑post. |

## Appendix B — Edge Function & cron registry
Deno Edge Functions live in `supabase/functions/<name>`. Each is stateless, idempotent, host‑allow‑listed (§43 A10), and logs with a correlation_id. "Trigger" = how it runs. Cron times are property‑TZ‑aware where they act per property (the scheduler runs UTC; functions resolve local windows).

| Function | Trigger | Purpose | Idempotency / notes |
|---|---|---|---|
| `chapa-webhook` | HTTP (Chapa) | Verify signature (§49 #3), match `tx_ref`, mark payment paid/failed, refresh folio | Replay‑safe: unique on provider ref; re‑posts no‑op |
| `telebirr-webhook` | HTTP (Telebirr) | Same for direct Telebirr path (if enabled) | Signature scheme §49 #4 |
| `mint-impersonation` | HTTP (platform_admin, authed) | Issue time‑boxed token with `imp` claim (≤60 min), write audit | Rejects if active session for tenant exists |
| `invoice-pdf` | HTTP (post‑issue) + retry queue | Render bilingual invoice/credit‑note PDF → `invoices` bucket | Keyed by invoice id; overwrite‑safe |
| `notify-dispatch` | DB queue trigger + 1‑min sweep | Render template (locale, per‑tenant override) + send via email/SMS adapter | Retries 1m/5m/30m/2h → `dead` + ops alert; per‑row lock |
| `ical-sync` | Cron 10 min | Pull each mapped iCal, diff events, write reservations/conflicts; serve export feeds | Per‑type advisory lock; conflicts → queue (D‑082) |
| `hold-expiry` | Cron 5 min | Expire holds past TTL, release inventory, notify creators | Set‑based; safe to re‑run |
| `cutoff-release` | Cron hourly | Release unpicked group allotment past cutoff back to inventory | Idempotent per block |
| `rate-materializer` | Cron nightly + on‑demand (D‑052) | Resolve plan+season+restriction → rate cache for the horizon | Recompute is deterministic; per‑plan lock |
| `saas-invoicer` | Cron monthly (1st) | Generate `saas_invoices` per active tenant (plan × properties) | Unique on tenant+period |
| `saas-dunning` | Cron daily | Advance dunning (day 0/3/7), flip statuses, send `saas_dunning_*` | Keyed by invoice+stage; no double‑send |
| `sla-watch` | Cron 15 min | Flag breached WOs, escalate to manager/owner | Marks `escalated_at` once |
| `audit-watch` | Cron hourly (00:00–06:00 focus) | Detect a property whose audit hasn't run past window → escalate | One alert per business_date |
| `ops-watch` | Cron 5 min | Business alerts S1–S3 (§30): stuck payments, dead notifications, dispatch backlog | Dedup by signature+window |
| `tenant-export` | HTTP (owner/platform) | Build full or guest‑scoped export (JSON+PDF) → signed URL | Rate‑limited; §32.3 / D‑065 |
| `backup-export` | Cron nightly | `pg_dump` logical backup → `backups` bucket → mirror to R2 | Timestamped; retention pruned |
| `backup-verify` | Cron weekly | Restore latest dump into throwaway DB, run row‑count + pgTAP smoke, report | Alerts on drift/failure (§32) |
| `retention-sweeper` | Cron daily | Enforce §33 schedule (purge/anonymize past‑retention rows) respecting legal holds | Dry‑run log before delete; batched |
| `health` | HTTP (synthetic monitor) | Liveness + shallow dependency checks (DB, storage, provider ping) | Public, unauthenticated, no data |

Cron offsets: stagger by function to avoid the 00:00 spike; audit‑sensitive jobs (`rate-materializer`, `backup-export`) run *after* the audit band per property or are safe to run concurrently (locks). All cron definitions are declared in `supabase/functions/_crons.ts` and mirrored in this table (drift check in CI).

## Appendix C — Seed & demo data specification
Two tiers: **reference seed** (required in every environment, deterministic) and **demo dataset** (dev/staging + optional per‑tenant "load demo" during provisioning, never in prod tenants by default).

### C.1 Reference seed (`supabase/seed/seed.sql`)
- **`et_admin_divisions`** — Region → Zone → Woreda → Kebele reference tree used by the guest address cascade (§22). Seeded from an authoritative list; versioned; app treats it read‑only.
- **Permission registry** — all ~45 keys (§6.2) inserted from `permissions.ts` codegen so DB and code never drift.
- **System roles → permission sets** — the 12 personas (§3) mapped to default permission bundles (owner = all tenant‑scoped; platform_admin = platform.* ; etc.).
- **Charge‑code packs** — standard hotel codes with Ethiopian VAT/service profiles (room, extra bed, laundry, minibar, airport transfer, restaurant, penalty/late/early, cash‑over‑short GL bucket).
- **Tax profiles** — VAT 15 % exclusive default, service 10 %, levy 0 % (flagged pending §49); computation order metadata (§41.2).
- **Notification templates** — every system key (§26) in en + am with correct variables.
- **HK checklist default** + **cancel/deposit policy exemplars** + **default flags/limits** per plan (§29).
- **Seed invariants test** (`pgTAP`): reference tables non‑empty, every permission key present, every template has both locales, every plan has a complete flag set.

### C.2 Demo dataset (`supabase/seed/demo/`)
A believable Harar boutique hotel — **"Engida Demo — Harar Gate Hotel"** — for screenshots, onboarding, and E2E:
- 1 tenant, 1 property (TZ Africa/Addis_Ababa), ~24 rooms across 3 types (Standard/Deluxe/Suite) with realistic ETB rates + a high/low season.
- Staff users covering every role (known passwords, dev‑only), each with least‑privilege mapping so role demos work.
- ~60 guests with Ethiopian names/addresses (valid division refs) + a few international; 2 companies with AR + credit limits; 1 DNR‑warn and 1 DNR‑block example.
- Reservations spanning yesterday/today/next 30 days: in‑house stayovers, today's arrivals (for check‑in demos) and departures (for checkout), a hold near expiry, a group block with a partial rooming list, one OTA‑sourced (iCal) booking, one overbook scenario primed.
- A handful of open folios with mixed charges (room+tax posted by a pre‑run audit, POS posts, one company‑routed), one settled invoice + one credit note, one refund pending approval.
- HK board mid‑shift (dirty/clean/inspected mix, one discrepancy primed), 2 open work orders (one P1 breaching SLA), one OOO block.
- One completed night‑audit run in history + `v_daily_stats` row so reports render non‑empty.
- **Determinism:** demo builder is seeded (fixed RNG) and date‑relative (computes around `now()` so "today" always has arrivals) — re‑runnable, and gated behind `demo=true` provisioning option (Starter/dev only; a prod tenant never auto‑loads demo).

### C.3 Loading
`pnpm db:reset` (dev) = migrations → seed.sql → demo builder. Provisioning wizard's "load demo" (D‑075 S4) runs only the demo builder scoped to the new tenant. CI e2e uses reference seed + a minimal fixture subset (fast) rather than the full demo.

---

*End of Engida Cloud HMS — Master Blueprint & Specification v1. Every module workflow, state machine, dialog (D‑001–D‑082), operations surface, configuration flag, error path, and delivery gate defined above is intended to be buildable without further assumption; the only deliberately open items are the eight §49 runtime confirmations, each isolated behind a configurable flag rather than a code change.*
