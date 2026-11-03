#!/usr/bin/env bash
# Copy this host's coding-agent session transcripts into the traces R2 bucket.
#
# Objects land at <bucket>/<host>/<path under $HOME>. The copy never deletes
# remote objects, so the bucket keeps every session even after a host prunes
# or loses its local history. Credentials come from Doppler agents/prd through
# the host's scoped agents-prd identity; a host without them skips the run.
set -euo pipefail

HOST_NAME="@host@"
IDENTITY_FILE="${TRACES_R2_IDENTITY_FILE:-${HOME}/.config/agenix/agents-prd.env}"
SECRET_NAMES=(TRACES_R2_ACCESS_KEY_ID TRACES_R2_SECRET_ACCESS_KEY TRACES_R2_ENDPOINT)

# Session stores, relative to $HOME, that the agent CLIs on fleet hosts write.
SESSION_PATHS=(
  ".claude/projects"
  ".codex/sessions"
  ".codex-t3/sessions"
  ".gemini/tmp"
  ".pi/agent/sessions"
  ".local/share/opencode/storage"
  ".goose/sessions"
)

read_identity_token() {
  [ -r "$IDENTITY_FILE" ] || return 0
  local line value
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
    DOPPLER_TOKEN=* | "export DOPPLER_TOKEN="*)
      value="${line#*DOPPLER_TOKEN=}"
      value="${value%\"}"
      value="${value#\"}"
      value="${value%\'}"
      value="${value#\'}"
      printf '%s' "$value"
      return 0
      ;;
    esac
  done <"$IDENTITY_FILE"
}

token="$(read_identity_token)"
if [ -z "$token" ]; then
  echo "traces-r2-sync: no agents-prd Doppler identity at $IDENTITY_FILE, skipping" >&2
  exit 0
fi

# An empty config dir keeps Doppler from reaching for a desktop keyring, which
# never answers on headless hosts.
config_dir="$(mktemp -d)"
trap 'rm -rf "$config_dir"' EXIT
if ! secrets_json="$(
  DOPPLER_TOKEN="$token" DOPPLER_CONFIG_DIR="$config_dir" \
    doppler secrets get "${SECRET_NAMES[@]}" \
    --project agents --config prd --json --silent 2>/dev/null
)"; then
  echo "traces-r2-sync: ${SECRET_NAMES[*]} not readable from Doppler agents/prd, skipping" >&2
  exit 0
fi

secret() {
  jq -er --arg name "$1" '.[$name].computed // empty' <<<"$secrets_json"
}

# Keep the values in rclone's environment-backed remote, never on argv.
RCLONE_CONFIG_R2_TYPE=s3
RCLONE_CONFIG_R2_PROVIDER=Cloudflare
RCLONE_CONFIG_R2_ACCESS_KEY_ID="$(secret TRACES_R2_ACCESS_KEY_ID)"
RCLONE_CONFIG_R2_SECRET_ACCESS_KEY="$(secret TRACES_R2_SECRET_ACCESS_KEY)"
RCLONE_CONFIG_R2_ENDPOINT="$(secret TRACES_R2_ENDPOINT)"
# A bucket-scoped token cannot create or inspect buckets.
RCLONE_CONFIG_R2_NO_CHECK_BUCKET=true
export RCLONE_CONFIG_R2_TYPE RCLONE_CONFIG_R2_PROVIDER RCLONE_CONFIG_R2_ACCESS_KEY_ID \
  RCLONE_CONFIG_R2_SECRET_ACCESS_KEY RCLONE_CONFIG_R2_ENDPOINT RCLONE_CONFIG_R2_NO_CHECK_BUCKET
unset token secrets_json

bucket="${TRACES_R2_BUCKET:-traces}"
status=0
for relative in "${SESSION_PATHS[@]}"; do
  source_dir="${HOME}/${relative}"
  [ -d "$source_dir" ] || continue
  echo "traces-r2-sync: ${source_dir} -> r2:${bucket}/${HOST_NAME}/${relative}" >&2
  # Live sessions append to their transcript while it uploads; the next run
  # picks up the newer copy instead of failing this one.
  rclone copy "$source_dir" "r2:${bucket}/${HOST_NAME}/${relative}" \
    --local-no-check-updated \
    --transfers 4 \
    --checkers 8 \
    --bwlimit 8M \
    --stats-one-line \
    --stats 0 ||
    status=$?
done
exit "$status"
