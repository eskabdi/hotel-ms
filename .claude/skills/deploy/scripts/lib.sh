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

# The Supabase CLI itself only reads SUPABASE_ACCESS_TOKEN. This environment
# currently has it set under the misspelled SUPABASE_ACCESSS_TOKEN (extra S)
# instead — tolerate that name too rather than block on a container restart,
# but prefer the correctly-spelled one and export it either way so `supabase`
# subcommands actually pick it up.
require_supabase_access_token() {
  if [ -n "${SUPABASE_ACCESS_TOKEN:-}" ]; then
    return 0
  fi
  if [ -n "${SUPABASE_ACCESSS_TOKEN:-}" ]; then
    echo "note: using SUPABASE_ACCESSS_TOKEN (misspelled, extra S) — rename it to SUPABASE_ACCESS_TOKEN in the environment config when convenient." >&2
    export SUPABASE_ACCESS_TOKEN="$SUPABASE_ACCESSS_TOKEN"
    return 0
  fi
  die "SUPABASE_ACCESS_TOKEN is not set. Add it as an environment variable in this session/environment config — never paste tokens into chat."
}

# A revoked/expired token fails every downstream call with the same generic
# error `supabase`/`vercel` give for a dozen other problems, well after
# you've already announced a plan to the user. Confirm it's live first, by
# status code only — never print the body, never print the token.
verify_supabase_token() {
  local code
  code="$(curl -sS -o /dev/null -w '%{http_code}' --max-time 10 \
    -H "Authorization: Bearer $SUPABASE_ACCESS_TOKEN" \
    https://api.supabase.com/v1/projects 2>/dev/null)" || true
  code="${code:-000}"
  case "$code" in
    200) return 0 ;;
    401|403) die "SUPABASE_ACCESS_TOKEN was rejected (HTTP $code) — it's invalid, expired, or revoked. Get a fresh one from the Supabase dashboard (Account -> Access Tokens) and update it in the environment config." ;;
    000) echo "note: couldn't reach api.supabase.com to verify SUPABASE_ACCESS_TOKEN (network/proxy blocked, or offline) — proceeding without pre-verification; the real command below will surface the actual failure if there is one." >&2 ;;
    *) echo "note: unexpected HTTP $code verifying SUPABASE_ACCESS_TOKEN — proceeding anyway, watch the next command's output." >&2 ;;
  esac
}

verify_vercel_token() {
  local code
  code="$(curl -sS -o /dev/null -w '%{http_code}' --max-time 10 \
    -H "Authorization: Bearer $VERCEL_TOKEN" \
    https://api.vercel.com/v2/user 2>/dev/null)" || true
  code="${code:-000}"
  case "$code" in
    200) return 0 ;;
    401|403) die "VERCEL_TOKEN was rejected (HTTP $code) — it's invalid, expired, or revoked. Get a fresh one from Vercel (Account Settings -> Tokens) and update it in the environment config." ;;
    000) echo "note: couldn't reach api.vercel.com to verify VERCEL_TOKEN (network/proxy blocked, or offline) — proceeding without pre-verification; the real command below will surface the actual failure if there is one." >&2 ;;
    *) echo "note: unexpected HTTP $code verifying VERCEL_TOKEN — proceeding anyway, watch the next command's output." >&2 ;;
  esac
}

# Vercel writes pulled project env vars (which can include real secrets like
# a service-role key, per blueprint §47) to .vercel/.env*.local on disk.
# .gitignore already excludes them (.vercel, *.local), but "ignored" is not
# "absent" — the next `git add -f`, tarball, or archive of this directory
# picks them up regardless. Delete them once the build that needed them is
# done, the same way you'd revoke a credential rather than just hide it.
cleanup_pulled_vercel_env() {
  local dir="$1"
  find "$dir/.vercel" -maxdepth 1 -name '.env*.local' -type f -delete 2>/dev/null || true
}

# A deploy isn't done when the artifact is live — it's done when nothing the
# deploy touched left a credential sitting in the working tree. Run this as
# the last step of any real (--yes) deploy; it's a sanity net, not a
# substitute for gitignore, and it never prints file contents, only names.
warn_if_untracked_files_look_secret() {
  local hits
  hits="$(git -C "$REPO_ROOT" status --porcelain --untracked-files=all 2>/dev/null \
    | awk '{print $2}' \
    | grep -E '\.env(\.|$)|\.local$|secret|token|credential' || true)"
  if [ -n "$hits" ]; then
    echo "note: these untracked/modified paths look credential-shaped — confirm none of them actually holds a secret before this is pushed or archived:" >&2
    while IFS= read -r line; do echo "  $line" >&2; done <<< "$hits"
  fi
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
