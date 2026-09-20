#!/usr/bin/env bash
# Merge the managed T3 Code provider instances into the app-owned server
# settings file. T3 rewrites this file on every load and setting change, so this
# only ever adds or updates the managed instances and leaves the rest alone.
#
# Usage: activate-settings.sh <managed_settings_json> <jq_bin> <env_file> <state_dir> <codex_home_config>
set -euo pipefail

MANAGED_SETTINGS="$1"
JQ_BIN="$2"
ENV_FILE="$3"
STATE_DIR="$4"
CODEX_HOME_CONFIG="${5:-}"
CODEX_HOME_DIR="${HOME}/.codex-t3/cliproxy"

SETTINGS="${STATE_DIR}/settings.json"
TEMP_SETTINGS=""

cleanup() {
  if [ -n "$TEMP_SETTINGS" ]; then
    rm -f "$TEMP_SETTINGS"
  fi
}
trap cleanup EXIT

mkdir -p "$STATE_DIR"
TEMP_SETTINGS="$(mktemp "${STATE_DIR}/settings.json.XXXXXX")"

# The managed template injects the CLIProxy credential at activation time; never
# commit the value itself. T3 Code owns this file, so prefer the ambient value
# and only fall back to the shared dotenv.
CLIPROXY_API_KEY="${CLIPROXY_API_KEY:-}"
if [ -z "$CLIPROXY_API_KEY" ] && [ -f "$ENV_FILE" ]; then
  CLIPROXY_API_KEY="$(
    set -a
    # shellcheck source=/dev/null
    . "$ENV_FILE" >/dev/null 2>&1
    set +a
    printf '%s' "${CLIPROXY_API_KEY:-}"
  )"
fi
if [ -z "$CLIPROXY_API_KEY" ]; then
  echo "Warning: CLIPROXY_API_KEY not found; the T3 Code CLIProxy instance stays unauthenticated" >&2
fi

# The Codex instance uses its own CODEX_HOME so its provider config and model
# list stay independent of the login-backed ~/.codex home.
if [ -n "$CODEX_HOME_CONFIG" ] && [ -f "$CODEX_HOME_CONFIG" ]; then
  mkdir -p "$CODEX_HOME_DIR"
  cp -f "$CODEX_HOME_CONFIG" "${CODEX_HOME_DIR}/config.toml"
fi

if [ -f "$SETTINGS" ] && ! "$JQ_BIN" empty "$SETTINGS" >/dev/null 2>&1; then
  echo "Warning: T3 Code server settings are malformed, leaving them unchanged: $SETTINGS" >&2
  exit 0
fi

if [ -f "$SETTINGS" ]; then
  # shellcheck disable=SC2016
  "$JQ_BIN" --slurpfile managed "$MANAGED_SETTINGS" --arg key "$CLIPROXY_API_KEY" '
    ($managed[0]) as $managed_settings
    | .providers = ((.providers // {}) * ($managed_settings.providers // {}))
    | .providerInstances =
        ((.providerInstances // {})
         * ($managed_settings.providerInstances
            | walk(
                if type == "string" then
                  if . == "__CLIPROXY_API_KEY__" and $key != "" then $key else . end
                else . end
              )))
  ' "$SETTINGS" >"$TEMP_SETTINGS"
else
  # shellcheck disable=SC2016
  "$JQ_BIN" --slurpfile managed "$MANAGED_SETTINGS" --arg key "$CLIPROXY_API_KEY" '
    ($managed[0]) as $managed_settings
    | $managed_settings
    | .providerInstances |= walk(
        if type == "string" then
          if . == "__CLIPROXY_API_KEY__" and $key != "" then $key else . end
        else . end
      )
  ' -n >"$TEMP_SETTINGS"
fi

mv -f "$TEMP_SETTINGS" "$SETTINGS"
chmod 600 "$SETTINGS"
trap - EXIT
