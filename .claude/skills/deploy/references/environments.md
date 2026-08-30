# Environment matrix

Source of truth for the *non-secret* identifiers is `scripts/environments.json` —
the scripts read it directly. This file is the human-readable version plus the
full matrix from blueprint §47, including the parts that aren't wired into the
scripts (yet, or ever — some of §47 is app-level config, not deploy config).

## Current state (2026-08-30)

| | dev | staging | prod |
|---|---|---|---|
| Supabase project | `hcwcxsijcozoqlrrisjf` (exists) | **not created** | **not created** |
| Vercel | single project `prj_kJJMsHMpAEL7mRTea2mNfFpKFBFG`, environments differentiated by `--prod` flag / git branch | same project, preview env | same project, production env |
| Web domain | Vercel preview URLs | not set | not set |

Only `dev` is real right now. `deploy-supabase.sh staging` and `deploy-supabase.sh prod`
will refuse to run (by design — see `scripts/lib.sh:require_provisioned_supabase`)
until someone actually creates those projects and fills in their refs below.

## Provisioning a new environment (staging or prod)

1. Create the Supabase project in the dashboard (org: same org as dev). Note its project ref and URL.
2. Update `scripts/environments.json`: set `provisioned: true`, `project_ref`, `url` for that environment.
3. Update the table above in this file.
4. Apply all migrations from zero to the new project: `deploy-supabase.sh <env>` (dry-run), review, then `--yes`.
5. Set Edge Function secrets on the new project (`supabase secrets set ...` — see "Function secrets" below); none exist yet since no functions have landed, but staging/prod will need this before P2 (payments) lands.
6. If a custom domain is involved (staging.engida.et, app.engida.et), add it in the Vercel dashboard and set `web_domains.<env>` in `environments.json` so `deploy-vercel.sh` can alias to it automatically.
7. Add the new environment's `VITE_SUPABASE_URL` / `VITE_SUPABASE_ANON_KEY` as Vercel project environment variables (dashboard → Settings → Environment Variables, scoped to Preview or Production) — these are pulled automatically by `vercel pull` during deploy, not committed anywhere.

## Full env matrix (blueprint §47)

This is the target state per the blueprint — most of the non-deploy rows
(email/SMS/payment provider config, Sentry sampling, cron offsets, flag
defaults) are application-level config read from Supabase project settings
or `flags.ts`, not something this deploy skill sets. Listed here so you know
what "done" looks like and don't confuse deploy-skill scope with app config.

| Concern | dev | staging | prod |
|---|---|---|---|
| Supabase project | engida-dev | engida-staging | engida-prod |
| Web host | Vercel preview URLs | staging.engida.et | app.engida.et |
| Auth redirect/allowed URLs | localhost:5173 + previews | staging domain | app domain only |
| JWT expiry / refresh | 60 min / 30 d | same | same |
| Email | Resend sandbox | Resend, `staging-notify@` | Resend prod domain, DKIM/SPF/DMARC |
| SMS | mock adapter (logs) | gateway sandbox | gateway prod, registered sender ID |
| Chapa/Telebirr | test keys, webhook → dev tunnel | test keys | live keys |
| Backups | PITR only | PITR + nightly dump | PITR (7d) + nightly dump + R2 mirror + weekly verify-restore |
| Sentry env tag | dev (10% sampled) | staging (100%) | prod (100% errors, 10% traces) |
| Cron schedules | manual trigger only | real, offset +5 min | real (Appendix B times) |
| Flags default | all modules on, limits high | prod-like | per plan §29 |

## Client env vars (`.env.example` / Vercel project env vars)

Per environment, scoped in the Vercel dashboard (Preview vs Production), never committed:
`VITE_SUPABASE_URL`, `VITE_SUPABASE_ANON_KEY`, `VITE_APP_ENV`, `VITE_SENTRY_DSN`.

Only the first two exist in `.env.example` today — `VITE_APP_ENV` and
`VITE_SENTRY_DSN` aren't consumed by the app yet (no Sentry wiring landed).
Don't add them to `.env.example` until the code that reads them exists.

## Edge Function secrets (`supabase secrets set`, per project)

`RESEND_API_KEY`, `SMS_GATEWAY_URL`, `SMS_GATEWAY_KEY`, `CHAPA_SECRET_KEY`,
`CHAPA_WEBHOOK_SECRET`, `TELEBIRR_APP_ID`, `TELEBIRR_APP_KEY`,
`TELEBIRR_PUBLIC_KEY`, `R2_ACCOUNT_ID`, `R2_ACCESS_KEY_ID`,
`R2_SECRET_ACCESS_KEY`, `R2_BUCKET_BACKUPS`, `PLATFORM_ALERT_EMAIL`,
`IMPERSONATION_SIGNING_KEY`.

None of this is needed yet — no Edge Functions exist in `supabase/functions/`
(payments/email/SMS land in phase P2 per blueprint §48). `deploy-supabase.sh`
already no-ops the functions-deploy step while that directory is empty.
