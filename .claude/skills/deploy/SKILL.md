---
name: deploy
description: Deploy Engida HMS — push Supabase migrations (and Edge Functions) to a real project and build/deploy apps/web to Vercel, for dev, staging, or prod. Use this whenever the user asks to deploy, ship, release, push migrations to a live/real Supabase project, run `supabase db push` against dev/staging/prod, promote a build, or get the app live/onto Vercel — even if they just say "deploy this" or "push the migration" without naming Supabase or Vercel explicitly. Do not use this for local development (`supabase start`, `pnpm dev`) or for the CI job that applies migrations to an ephemeral local Postgres — that's a correctness check, not a deploy, and is already handled by `.github/workflows/ci.yml`.
---

# Deploying Engida HMS

This repo's actual deploy tooling is thinner than the blueprint's target
pipeline (§46/§47) — no `deploy.yml` exists yet, only one Supabase project
(`dev`) is provisioned, and Vercel has a single project not yet linked
locally. This skill's scripts are what stand in for the missing automation:
read `references/pipeline.md` once if you want the full picture of what's
real vs. aspirational; the short version is below.

## Why this isn't "just run the CLI"

Every command here either writes to a real database other people query, or
publishes a build other people load in a browser. That's exactly the kind of
hard-to-reverse, shared-state action the general "confirm before acting"
rule exists for — so the scripts are built so that **plan and apply are two
separate steps**, not because the tooling is fragile but because a wrong
migration or a bad prod build is not something `git revert` fixes:

- `deploy-supabase.sh <env>` with no `--yes` only links the project and runs
  `supabase db push --dry-run` — it shows you the pending migrations and
  changes nothing.
- `deploy-vercel.sh <env>` with no `--yes` links the project and runs a real
  local build (`vercel build`) — it proves the build succeeds and changes
  nothing.
- Only re-running either with `--yes` actually applies/publishes.

Always run the dry-run pass, show the plan to the user, and get an explicit
go-ahead before re-running with `--yes` — for every environment, not just
prod. `dev` is lower-stakes but it's still a real shared project, not a
sandbox that resets itself.

## Credentials

Three secrets, three different jobs — don't conflate them:

- `SUPABASE_ACCESS_TOKEN` — account-level personal access token. Authenticates
  the `supabase` CLI for `link`/`db push`/`functions deploy`. Not a project
  key; a leaked one reaches every project on the account, not just this one.
- `SUPABASE_DB_PASSWORD` — this project's Postgres password. Needed for
  `supabase link` alongside the access token.
- `VERCEL_TOKEN` — account-level token authenticating the `vercel` CLI.

None of these are secrets this skill's scripts ever hold responsibility for
storing — they live only in this session/environment's own variable config,
for the whole session, and that is the **only** place they may live:

- **Never accept one pasted into chat.** If a user pastes a token or password
  anyway, don't use it from the chat text — the value is already exposed the
  moment it's typed there (chat transcripts aren't a secret store the way
  session env vars are), so treat it as compromised and tell the user to
  rotate/reset it, then set the new value the correct way.
- **Never write one into a file, a commit, a commit message, or any command
  output** — not even a gitignored one ("ignored" is not "absent": the next
  `git add -f`, tarball, or directory archive picks it up regardless). If a
  step needs to pass a secret to a subprocess, pass it as an env var or a
  CLI flag sourced from the env var (as the scripts here do) — never
  interpolate it into a file on disk.
- **Confirm a token is actually valid before trusting a plan built on it.**
  A revoked token fails deep into a migration push with the same generic
  error as a dozen unrelated problems — `verify_supabase_token` /
  `verify_vercel_token` in `scripts/lib.sh` check by HTTP status code only
  (200 vs. 401/403), calling `die` on a confirmed-invalid token before any
  real command runs. They never print the token or the response body. If
  the check itself can't reach the API (network/proxy policy — this
  sandbox's own egress proxy blocks `api.supabase.com` outright, for
  example), they warn and let the real command surface the actual failure
  rather than blocking on an inconclusive check.
- **Vercel pulls real secrets to disk.** `vercel pull` (used by
  `deploy-vercel.sh`) writes the linked project's environment variables —
  which per blueprint §47 includes things like a service-role key once one
  exists — to `.vercel/.env*.local`. That path is gitignored, but the script
  deletes those files itself right after the build/deploy that needed them
  (`cleanup_pulled_vercel_env` in `lib.sh`) rather than relying on gitignore
  alone to keep them out of a future commit or archive.
- **A deploy isn't finished when the artifact is live.** Both deploy scripts
  end with `warn_if_untracked_files_look_secret`, a `git status` sanity check
  that flags (by filename only, never contents) anything left in the working
  tree that looks credential-shaped — a cheap last check, not a replacement
  for the two points above.

## Workflow

1. **Check readiness first**: `scripts/check-env.sh [env]` — reports which
   CLIs/tokens are missing and whether the target environment's Supabase
   project is provisioned, without ever printing secret values. If
   credentials are missing, tell the user to add them as environment
   variables in this session/environment's config per the Credentials
   section above. Required: `SUPABASE_ACCESS_TOKEN`, `SUPABASE_DB_PASSWORD`,
   `VERCEL_TOKEN`.

2. **Confirm the target environment** if the user didn't say — don't guess
   between dev/staging/prod, the blast radius differs enormously between them.
   `staging` and `prod` will currently fail fast with a clear "not
   provisioned" error (see `references/environments.md`) since only `dev`
   exists — that's expected, not a bug to work around.

3. **Migrations** (`scripts/deploy-supabase.sh <env>`): dry-run, show the
   pending-migration list to the user, get confirmation, then `--yes`. Edge
   Function deploy is bundled into the same script and no-ops automatically
   while `supabase/functions/` is empty (true for the whole repo right now).

4. **Web build + deploy** (`scripts/deploy-vercel.sh <env>`): dry-run (real
   build, no publish), show the build result, get confirmation, then
   `--yes`. `prod` passes `--prod` to Vercel; `staging` deploys as a preview
   and attempts to alias it to `web_domains.staging` from
   `scripts/environments.json` if one is configured there (none is yet).

5. **Order matters**: migrations before web deploy, so the newly-deployed
   frontend never queries a schema it predates. If a migration and a web
   deploy are both needed, do the Supabase step first, confirm it's applied,
   then do Vercel.

6. **Prod-specific hard rule**: both scripts refuse to run against `prod`
   during 00:00–06:00 EAT (the night-audit band, blueprint §46) — this is a
   real refusal (non-zero exit), not a prompt you can talk past, because
   that window is when Night Audit runs and a migration or redeploy landing
   mid-audit is the exact failure mode D-15 (business-date, not wall clock)
   exists to prevent. Outside that band but off the 22:00 EAT default
   window, the scripts only warn — flag it to the user and let them decide.

## Sandboxed / network-restricted sessions

Some sessions run behind an egress proxy that only allowlists specific
hosts — `api.supabase.com` and `api.vercel.com` are not guaranteed to be on
it. If `deploy-supabase.sh`/`deploy-vercel.sh` fail with a proxy
CONNECT/403-style error rather than an auth or CLI error, that's a network
policy block, not a credentials problem or a bug in these scripts — don't
try to route around it (no alternate hosts, no disabling proxy/TLS
settings). Report the blocked host to the user; live deploys from a session
in that state need to happen from an environment with broader network
access, or the policy needs to allow the host.

## When the target environment doesn't exist yet

If the user asks to deploy to `staging` or `prod` and `check-env.sh` reports
it's not provisioned, don't try to work around it (e.g. by pointing prod
config at the dev project — that would silently merge environments the
blueprint deliberately keeps separate). Walk the user through
`references/environments.md`'s provisioning checklist instead, and update
`scripts/environments.json` once the real project exists.

## Files

- `scripts/check-env.sh` — preflight: what's missing, what's provisioned.
- `scripts/deploy-supabase.sh <dev|staging|prod> [--yes]` — migrations + functions.
- `scripts/deploy-vercel.sh <dev|staging|prod> [--yes]` — build + deploy apps/web.
- `scripts/lib.sh` — shared helpers: env var checks, the EAT audit-band gate, and everything in the Credentials section above (token verification, pulled-env cleanup, the end-of-deploy secret-shaped-file check). Sourced by the other scripts, not run directly.
- `scripts/environments.json` — non-secret project refs/IDs the scripts read. Update this (and `references/environments.md`) when staging/prod get provisioned — don't hardcode refs elsewhere.
- `references/environments.md` — full env matrix (blueprint §47), current provisioning state, how to add a new environment.
- `references/pipeline.md` — what CI does today vs. the blueprint's target pipeline, migration conventions, rollback approach.
