---
name: deploy
description: Migrate DB to Supabase (prod project) and deploy apps/web to Vercel. Use when user says "deploy", "ship this", "migrate to supabase", "deploy to vercel", or "release".
---

# Deploy: Supabase + Vercel

Two independent phases. DB migration is riskier — confirm with user before applying to prod. Vercel deploy is push-triggered once configured; only needed once per project.

## Phase 1 — Supabase (prod project migration)

Repo has only a dev Supabase project wired (`hcwcxsijcozoqlrrisjf`, in `.env.example`). Prod project must exist separately (create at supabase.com/dashboard if not yet done — ask user for the project ref if unknown, don't guess it).

1. Confirm prod project ref with user. Never assume dev ref = prod ref.
2. Link CLI to prod project (one-time, from repo root):
   ```
   supabase link --project-ref <PROD_REF>
   ```
3. Dry-run diff first — never push blind:
   ```
   supabase db diff --linked
   ```
4. Review output. Migrations are forward-only (`supabase/migrations/0001...0008`, see CLAUDE.md) — no edits to already-applied files.
5. Push:
   ```
   pnpm db:push
   ```
   (= `supabase db push`, applies pending migrations 0001–0008+ against linked prod DB)
6. Verify RLS: every table must show `rowsecurity = true` AND `forcerowsecurity = true`. Spot check:
   ```sql
   select relname, relrowsecurity, relforcerowsecurity
   from pg_class where relnamespace = 'public'::regnamespace;
   ```
7. Confirm the custom-access-token Auth Hook (migration 0008) is enabled in prod: Dashboard → Authentication → Hooks. CLI push does not auto-enable hooks in the dashboard toggle — check manually.
8. Grab prod `anon` key + URL from Dashboard → Settings → API. These go into Vercel env vars, not into any repo file.

**Never** run `supabase db reset` against a linked prod project — that command is dev-only (wipes + reseeds). Confirm which project is linked (`supabase projects list` / check `supabase/.temp/project-ref`) before any destructive command.

## Phase 2 — Vercel (apps/web)

Monorepo (pnpm workspaces), so Vercel project root must stay the repo root with these settings (Project Settings → Build & Development, or `vercel.json` at repo root):

- **Root Directory:** repo root (leave default) — do NOT set it to `apps/web`, since the build needs `packages/shared-types` as a workspace sibling.
- **Install Command:** `pnpm install --frozen-lockfile`
- **Build Command:** `pnpm --filter web build`
- **Output Directory:** `apps/web/dist`
- **Framework Preset:** Vite

SPA rewrite is required — TanStack Router does client-side routing, so all paths must fall through to `index.html` or deep links 404 on refresh.

Root Directory stays repo root, so `vercel.json` goes at **repo root** (not inside `apps/web`):

```json
{
  "buildCommand": "pnpm --filter web build",
  "installCommand": "pnpm install --frozen-lockfile",
  "outputDirectory": "apps/web/dist",
  "rewrites": [{ "source": "/(.*)", "destination": "/index.html" }]
}
```

### Steps

1. Check for existing project: `vercel project ls` (Vercel CLI must be installed + logged in — if not, tell user to run `vercel login` interactively, don't attempt it yourself non-interactively).
2. First-time only, from repo root: `vercel link` — links this repo to a Vercel project.
3. Set env vars (prod + preview) — pull prod values from Supabase Phase 1 step 8:
   ```
   vercel env add VITE_SUPABASE_URL production
   vercel env add VITE_SUPABASE_ANON_KEY production
   ```
   Repeat with `preview` target so PR previews work against... decide with user whether previews hit prod or a separate staging Supabase project (recommended: staging project, to avoid preview branches writing to prod data).
4. Deploy:
   - Preview: `vercel`
   - Production: `vercel --prod`
5. After first deploy, confirm client-side routing works: hit a deep route directly (not just `/`) and hard-refresh — verifies the rewrite rule is live, not just the SPA's own router.

### CI note

`.github/workflows/ci.yml` already runs lint/typecheck/build + pgTAP RLS coverage on every PR and push to `main`. If Vercel's Git integration is connected, it deploys independently of this CI — a green Vercel preview does not mean CI passed and vice versa. Treat both as required before calling a deploy done.

## Guardrails

- D-23 (server trust) means a bad Vercel deploy can't leak more than what RLS already allows — but a bad Supabase migration (RLS not forced) can. Phase 1 step 6 is not optional.
- Ask before Phase 1 if unsure which Supabase project is prod — wrong `--project-ref` silently migrates the wrong DB.
- Ask before any `vercel --prod` if this is the user's first production deploy — confirm env vars are prod values, not dev ones copied from `.env.example`.
