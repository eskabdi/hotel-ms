#!/usr/bin/env bash
# Push pending migrations (and Edge Functions, if any exist) to a real Supabase
# project. Always run WITHOUT --yes first — that only links the project and
# shows what would change (supabase db push --dry-run). Nothing is applied
# for real until you re-run with --yes, after a human has looked at the plan.
#
# Usage: deploy-supabase.sh <dev|staging|prod> [--yes]

set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
source ./lib.sh

TARGET="${1:-}"
APPLY="false"
[ "${2:-}" = "--yes" ] && APPLY="true"

case "$TARGET" in
  dev|staging|prod) ;;
  *) die "usage: deploy-supabase.sh <dev|staging|prod> [--yes]" ;;
esac

require_cmd supabase supabase
require_cmd jq jq
require_provisioned_supabase "$TARGET"
require_env_var SUPABASE_ACCESS_TOKEN
require_env_var SUPABASE_DB_PASSWORD

if [ "$TARGET" = "prod" ]; then
  assert_outside_audit_band
  warn_outside_deploy_window
fi

REF="$(env_field ".supabase.\"$TARGET\".project_ref")"
echo "== target: $TARGET (project_ref: $REF) =="

echo "== linking =="
supabase link --project-ref "$REF" --password "$SUPABASE_DB_PASSWORD"

if [ "$APPLY" = "false" ]; then
  echo "== DRY RUN — pending migrations that WOULD be applied to $TARGET =="
  supabase db push --linked --dry-run
  echo
  echo "Nothing was applied. Review the plan above with the user, then re-run:"
  echo "  deploy-supabase.sh $TARGET --yes"
  exit 0
fi

echo "== applying migrations to $TARGET =="
supabase db push --linked

# Only attempt a functions deploy if any function directories actually exist —
# none do yet in this repo (no supabase/functions/<name>/index.ts landed),
# and `supabase functions deploy` with nothing to deploy is just noise.
FUNCTIONS_DIR="$REPO_ROOT/supabase/functions"
if [ -d "$FUNCTIONS_DIR" ] && [ -n "$(find "$FUNCTIONS_DIR" -mindepth 1 -maxdepth 1 -type d 2>/dev/null)" ]; then
  echo "== deploying edge functions to $TARGET =="
  supabase functions deploy --project-ref "$REF"
else
  echo "== no edge functions in supabase/functions/ yet — skipping functions deploy =="
fi

echo "== done: $TARGET migrations applied =="
