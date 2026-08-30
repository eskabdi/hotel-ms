#!/usr/bin/env bash
# Build and deploy apps/web to Vercel. Always run WITHOUT --yes first — that
# links the project and runs a real local build (vercel build) without
# publishing anything. Nothing is deployed for real until you re-run with
# --yes, after a human has looked at the build output.
#
# Usage: deploy-vercel.sh <dev|staging|prod> [--yes]

set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
source ./lib.sh

TARGET="${1:-}"
APPLY="false"
[ "${2:-}" = "--yes" ] && APPLY="true"

case "$TARGET" in
  dev|staging|prod) ;;
  *) die "usage: deploy-vercel.sh <dev|staging|prod> [--yes]" ;;
esac

require_cmd vercel vercel
require_cmd jq jq
require_env_var VERCEL_TOKEN

if [ "$TARGET" = "prod" ]; then
  assert_outside_audit_band
  warn_outside_deploy_window
fi

PROJECT_ID="$(env_field ".vercel.project_id")"
ORG_ID="$(env_field ".vercel.org_id")"
ROOT_DIR="$(env_field ".vercel.root_directory")"
[ "$PROJECT_ID" = "null" ] && die "vercel.project_id is not set in environments.json"

WEB_DIR="$REPO_ROOT/$ROOT_DIR"
cd "$WEB_DIR"

VERCEL_ENV="preview"
PROD_FLAG=()
if [ "$TARGET" = "prod" ]; then
  VERCEL_ENV="production"
  PROD_FLAG=(--prod)
fi

LINK_ARGS=(link --yes --project="$PROJECT_ID" --token="$VERCEL_TOKEN")
if [ "$ORG_ID" != "null" ]; then
  LINK_ARGS+=(--org="$ORG_ID")
fi

echo "== target: $TARGET (vercel env: $VERCEL_ENV, dir: $ROOT_DIR) =="
echo "== linking =="
vercel "${LINK_ARGS[@]}"

echo "== pulling project settings/env vars =="
vercel pull --yes --environment="$VERCEL_ENV" --token="$VERCEL_TOKEN"

echo "== building =="
vercel build "${PROD_FLAG[@]}" --token="$VERCEL_TOKEN"

if [ "$APPLY" = "false" ]; then
  echo
  echo "Build succeeded. Nothing was deployed. Review the build output above with the user, then re-run:"
  echo "  deploy-vercel.sh $TARGET --yes"
  exit 0
fi

echo "== deploying (prebuilt) =="
DEPLOY_URL="$(vercel deploy --prebuilt "${PROD_FLAG[@]}" --token="$VERCEL_TOKEN")"
echo "== deployed: $DEPLOY_URL =="

if [ "$TARGET" = "staging" ]; then
  DOMAIN="$(env_field '.web_domains.staging')"
  if [ "$DOMAIN" != "null" ]; then
    echo "== aliasing $DEPLOY_URL -> $DOMAIN =="
    vercel alias set "$DEPLOY_URL" "$DOMAIN" --token="$VERCEL_TOKEN"
  else
    echo "note: web_domains.staging is not set in environments.json — deployed as a preview URL only, not promoted to a staging domain. Set the domain there once one exists, or run 'vercel alias set $DEPLOY_URL <domain>' manually."
  fi
fi

echo "== done: $TARGET deployed =="
