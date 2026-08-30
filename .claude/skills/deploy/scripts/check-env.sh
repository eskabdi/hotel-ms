#!/usr/bin/env bash
# Preflight check: is this environment actually able to deploy? Reports what's
# missing (CLIs, tokens, provisioning) without ever printing secret values.
# Run this first, before attempting deploy-supabase.sh or deploy-vercel.sh.
#
# Usage: check-env.sh [dev|staging|prod]   (defaults to checking all three)

set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
source ./lib.sh
set +e

ok=true
check() {
  if eval "$2" >/dev/null 2>&1; then
    echo "  [ok] $1"
  else
    echo "  [--] $1"
    ok=false
  fi
}

echo "CLIs:"
check "supabase CLI installed" "command -v supabase"
check "vercel CLI installed" "command -v vercel"
check "jq installed" "command -v jq"

echo "Credentials (presence only, values never shown):"
check "SUPABASE_ACCESS_TOKEN set (or SUPABASE_ACCESSS_TOKEN)" '[ -n "${SUPABASE_ACCESS_TOKEN:-}" ] || [ -n "${SUPABASE_ACCESSS_TOKEN:-}" ]'
check "SUPABASE_DB_PASSWORD set" '[ -n "${SUPABASE_DB_PASSWORD:-}" ]'
check "VERCEL_TOKEN set" '[ -n "${VERCEL_TOKEN:-}" ]'

TARGETS="${1:-dev staging prod}"
echo "Supabase provisioning:"
for t in $TARGETS; do
  p="$(env_field ".supabase.\"$t\".provisioned" 2>/dev/null)"
  if [ "$p" = "true" ]; then
    echo "  [ok] $t provisioned ($(env_field ".supabase.\"$t\".project_ref"))"
  else
    echo "  [--] $t not provisioned yet"
  fi
done

echo
if [ "$ok" = "true" ]; then
  echo "Ready to deploy (subject to per-environment provisioning above)."
else
  echo "Not ready — see [--] items above. Credentials go in this session's environment config, never pasted in chat."
fi
