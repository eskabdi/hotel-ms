# CI/CD pipeline — what exists vs. what's aspirational

Blueprint §46 describes the target pipeline. As of this writing only the
pre-merge PR gate is real; the actual deploy step described below is what
this skill's scripts stand in for until a `deploy.yml` workflow exists.

## What's real today: `.github/workflows/ci.yml`

Runs on every PR and on push to `main`. Two jobs:
- **app**: `pnpm install --frozen-lockfile` → `pnpm lint` → `pnpm typecheck` → `pnpm build`
- **db**: `supabase start` (applies every migration in `supabase/migrations/` from zero against a throwaway local Postgres) → `supabase test db` (pgTAP suite in `supabase/tests/`)

This is a correctness gate, not a deploy — it never touches the real dev/staging/prod
Supabase projects or Vercel. Merging to `main` today does **not** trigger any
deploy; nothing auto-deploys until someone runs this skill's scripts (or a
future `deploy.yml` is added).

## What's aspirational (blueprint §46, not built)

```
merge to main
  → auto deploy staging (Vercel preview promoted + supabase db push to
    engida-staging + functions deploy)
  → smoke suite runs against staging
  → manual approval gate
  → prod deploy window (default 22:00 EAT, never during 00:00–06:00 audit band)
     - prod migration: statement_timeout=5min, wrapped in advisory lock
     - rollback = redeploy previous web build + PITR only for data incidents
```

Until a `deploy.yml` automates this, treat every deploy as manual: run
`scripts/check-env.sh`, then `scripts/deploy-supabase.sh <env>` and
`scripts/deploy-vercel.sh <env>` yourself (dry-run first, `--yes` after
confirming the plan with the user). The scripts already enforce the one
hard rule from this pipeline that matters regardless of automation state —
no prod deploy during the 00:00–06:00 EAT audit band — so use them even for
a "quick manual deploy" rather than calling `supabase`/`vercel` raw.

## Migration conventions (apply to every environment, not just prod)

- Forward-only. No down scripts — recovery is Point-In-Time-Recovery, not a
  reverse migration.
- One logical change per file, paired with a `-- verify:` block (see existing
  migrations in `supabase/migrations/` for the pattern) — these assertions
  run as part of the CI `db` job, so a migration that doesn't verify itself
  fails on the PR before it ever reaches a deploy script.
- RLS policies live in dedicated `NNNN_rls_*.sql` files, kept separate from
  the table-defining migration, so RLS coverage is a reviewable diff on its
  own.
- A migration touching money tables (`folio_lines`, `payments`, `invoices` —
  none exist yet) needs a second reviewer per blueprint §46. No CODEOWNERS
  file exists yet to enforce this mechanically — it's currently a process
  rule, not a GitHub-enforced one.

## Rollback

There is no automated rollback script, by design (per blueprint: redeploy the
previous Vercel build for web issues; PITR for data incidents, run by whoever
owns the Supabase project — this is a human-judgment operation, not something
to script blindly). `vercel ls` / `vercel rollback` in the Vercel CLI can
redeploy a previous build; there's no equivalent "undo" for a pushed
migration — that's exactly why the dry-run-first pattern in
`deploy-supabase.sh` exists: catching a bad migration *before* `--yes` is the
only real safety net.
