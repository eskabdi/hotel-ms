#!/usr/bin/env bash
# Shared helpers for deploy-supabase.sh and deploy-vercel.sh.
# Not meant to be run directly — sourced by the other scripts.

set -euo pipefail

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_CONFIG="$SKILL_DIR/scripts/environments.json"
REPO_ROOT="$(cd "$SKILL_DIR/../../.." && pwd)"

die() { echo "error: $*" >&2; exit 1; }

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "$1 is not installed. Run: npm install -g $2"
}

require_env_var() {
  local name="$1"
  if [ -z "${!name:-}" ]; then
    die "$name is not set. Add it as an environment variable in this session/environment config — never paste tokens into chat."
  fi
}

env_field() {
  # env_field <jq-path> — reads a field out of environments.json
  jq -r "$1" "$ENV_CONFIG"
}

require_provisioned_supabase() {
  local target="$1"
  local provisioned
  provisioned="$(env_field ".supabase.\"$target\".provisioned")"
  if [ "$provisioned" != "true" ]; then
    die "Supabase project for '$target' is not provisioned yet (environments.json has it as provisioned:false). Create the project in the Supabase dashboard first, then fill in its project_ref/url in $ENV_CONFIG and references/environments.md — see that file for the full checklist."
  fi
}

# Current time in Africa/Addis_Ababa (EAT, UTC+3, no DST) — computed by
# fixed offset rather than relying on system tzdata, since the CI/session
# container's installed zoneinfo isn't guaranteed.
eat_hour_now() {
  local utc_epoch eat_epoch
  utc_epoch="$(date -u +%s)"
  eat_epoch=$((utc_epoch + 3 * 3600))
  date -u -d "@$eat_epoch" +%H
}

# Blueprint §46: prod deploys never run during the 00:00-06:00 EAT night-audit
# band, full stop — this isn't a soft preference, audit runs in that window
# and a migration or web redeploy landing mid-audit is exactly the kind of
# thing D-15 (business-date, not wall-clock) exists to prevent surprises around.
assert_outside_audit_band() {
  local h
  h="$(eat_hour_now)"
  h=$((10#$h))
  if [ "$h" -ge 0 ] && [ "$h" -lt 6 ]; then
    die "It's ${h}:xx EAT — inside the 00:00-06:00 night-audit band. Prod deploys are never run in this window (blueprint §46). Wait until after 06:00 EAT."
  fi
}

warn_outside_deploy_window() {
  local h
  h="$(eat_hour_now)"
  h=$((10#$h))
  if [ "$h" -ne 22 ]; then
    echo "note: default prod deploy window is 22:00 EAT (blueprint §46); it's currently ${h}:xx EAT. Not a hard block, but confirm this is intentional before proceeding." >&2
  fi
}
