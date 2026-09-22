#!/usr/bin/env bash
# Merge the managed T3 Code provider instances into the app-owned server
# settings file. T3 rewrites this file on every load and setting change, so this
# only ever adds or updates the managed instances and leaves the rest alone.
#
# Usage: activate-settings.sh <managed_settings_json> <jq_bin> <env_file> <state_dir> <codex_home_config> [systemctl_bin]
set -euo pipefail

MANAGED_SETTINGS="$1"
JQ_BIN="$2"
ENV_FILE="$3"
STATE_DIR="$4"
CODEX_HOME_CONFIG="${5:-}"
SYSTEMCTL_BIN="${6:-}"
CODEX_HOME_DIR="${HOME}/.codex-t3/cliproxy"

SETTINGS="${STATE_DIR}/settings.json"
SECRETS_DIR="${STATE_DIR}/secrets"
KEY_PLACEHOLDER='__CLIPROXY_API_KEY__'
TEMP_SETTINGS=""
TEMP_CODEX_AUTH=""

cleanup() {
  if [ -n "$TEMP_SETTINGS" ]; then
    rm -f "$TEMP_SETTINGS"
  fi
  if [ -n "$TEMP_CODEX_AUTH" ]; then
    rm -f "$TEMP_CODEX_AUTH"
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

# T3 Code keeps every `sensitive` instance value in its own secret store, one
# file per instance and variable named from their base64url without padding, and
# serves the provider from there rather than from the settings value. Render both
# or the instance runs on whatever the store already holds.
b64url() { printf '%s' "$1" | base64 | tr -d '\n=' | tr '+/' '-_'; }

managed_secrets=()
while IFS="$(printf '\t')" read -r instance variable; do
  [ -n "$instance" ] || continue
  managed_secrets+=("$SECRETS_DIR/provider-env-$(b64url "$instance")-$(b64url "$variable").bin")
done < <(
  # shellcheck disable=SC2016
  "$JQ_BIN" -r --arg placeholder "$KEY_PLACEHOLDER" '
    .providerInstances | to_entries[]
    | .key as $instance
    | .value.environment[]?
    | select(.sensitive == true and .value == $placeholder)
    | "\($instance)\t\(.name)"
  ' "$MANAGED_SETTINGS"
)

# A render that left the placeholder behind is kept as if it were a credential
# and every CLIProxy request fails. Drop those files whatever instance wrote
# them; the value is ours and is never a usable secret.
purged_secret=false
if [ -d "$SECRETS_DIR" ]; then
  for secret in "$SECRETS_DIR"/provider-env-*.bin; do
    [ -f "$secret" ] || continue
    [ "$(cat "$secret")" = "$KEY_PLACEHOLDER" ] || continue
    rm -f "$secret"
    purged_secret=true
  done
fi

# The dotenv is hydrated out of band, so a host can activate before it lands.
# Reuse the credential T3 already holds rather than blanking a working instance.
previous_key=''
if [ -f "$SETTINGS" ] && "$JQ_BIN" empty "$SETTINGS" >/dev/null 2>&1; then
  # shellcheck disable=SC2016
  previous_key="$("$JQ_BIN" -r --arg placeholder "$KEY_PLACEHOLDER" '
    [.providerInstances[]?.environment[]?
     | select(.name == "ANTHROPIC_AUTH_TOKEN" or .name == "CLIPROXY_API_KEY")
     | .value
     | select(type == "string" and . != "" and . != $placeholder)]
    | first // ""
  ' "$SETTINGS")"
fi
# T3 strips the value from the settings once it owns the secret, so the store is
# the only remaining copy on a host whose dotenv has since gone missing.
if [ -z "$previous_key" ]; then
  for secret in ${managed_secrets[@]+"${managed_secrets[@]}"}; do
    [ -f "$secret" ] || continue
    previous_key="$(cat "$secret")"
    [ -n "$previous_key" ] && break
  done
fi
if [ -z "$CLIPROXY_API_KEY" ]; then
  CLIPROXY_API_KEY="$previous_key"
fi

if [ -z "$CLIPROXY_API_KEY" ]; then
  echo "Warning: CLIPROXY_API_KEY not found; the T3 Code CLIProxy instances stay unauthenticated" >&2
fi

# The base URL is host-only: Claude Code appends /v1/messages, so a trailing /v1
# would produce /v1/v1/messages. Remote by default; a host running its own proxy
# overrides it.
CLIPROXY_BASE_URL="${CLIPROXY_BASE_URL:-https://cliproxy.shunkakinoki.com}"

# The Codex instance uses its own CODEX_HOME so its provider config and model
# list stay independent of the login-backed ~/.codex home.
if [ -n "$CODEX_HOME_CONFIG" ] && [ -f "$CODEX_HOME_CONFIG" ]; then
  mkdir -p "$CODEX_HOME_DIR"
  if [ ! -f "${CODEX_HOME_DIR}/config.toml" ] ||
    [ "$(<"$CODEX_HOME_CONFIG")" != "$(<"${CODEX_HOME_DIR}/config.toml")" ]; then
    cp -f "$CODEX_HOME_CONFIG" "${CODEX_HOME_DIR}/config.toml"
  fi

  # Codex refuses to start a session unless CODEX_HOME holds an auth record, and
  # that check runs before model_provider resolves, so the cliproxyapi provider's
  # env_key alone leaves the instance reported as logged out. This value is never
  # sent upstream: requests authenticate with CLIPROXY_API_KEY from the instance
  # environment.
  if [ -n "$CLIPROXY_API_KEY" ]; then
    CODEX_AUTH="${CODEX_HOME_DIR}/auth.json"
    TEMP_CODEX_AUTH="$(mktemp "${CODEX_AUTH}.XXXXXX")"
    # shellcheck disable=SC2016
    "$JQ_BIN" -n --arg key "$CLIPROXY_API_KEY" \
      '{OPENAI_API_KEY: $key, tokens: null, last_refresh: null}' >"$TEMP_CODEX_AUTH"
    chmod 600 "$TEMP_CODEX_AUTH"
    if [ ! -f "$CODEX_AUTH" ] || [ "$(<"$TEMP_CODEX_AUTH")" != "$(<"$CODEX_AUTH")" ]; then
      mv -f "$TEMP_CODEX_AUTH" "$CODEX_AUTH"
    else
      rm -f "$TEMP_CODEX_AUTH"
    fi
    TEMP_CODEX_AUTH=""
  fi
fi

if [ -f "$SETTINGS" ] && ! "$JQ_BIN" empty "$SETTINGS" >/dev/null 2>&1; then
  echo "Warning: T3 Code server settings are malformed, leaving them unchanged: $SETTINGS" >&2
  exit 0
fi

if [ -f "$SETTINGS" ]; then
  # shellcheck disable=SC2016
  "$JQ_BIN" --slurpfile managed "$MANAGED_SETTINGS" --arg key "$CLIPROXY_API_KEY" --arg base "$CLIPROXY_BASE_URL" '
    ($managed[0]) as $managed_settings
    | .providers = ((.providers // {}) * ($managed_settings.providers // {}))
    | .providerInstances =
        ((.providerInstances // {})
         * ($managed_settings.providerInstances
            | walk(
                if type == "string" then
                  if . == "__CLIPROXY_API_KEY__" then $key
                  elif . == "__CLIPROXY_BASE_URL__" then $base
                  else . end
                else . end
              )))
  ' "$SETTINGS" >"$TEMP_SETTINGS"
else
  # shellcheck disable=SC2016
  "$JQ_BIN" --slurpfile managed "$MANAGED_SETTINGS" --arg key "$CLIPROXY_API_KEY" --arg base "$CLIPROXY_BASE_URL" '
    ($managed[0]) as $managed_settings
    | $managed_settings
    | .providerInstances |= walk(
        if type == "string" then
          if . == "__CLIPROXY_API_KEY__" then $key
          elif . == "__CLIPROXY_BASE_URL__" then $base
          else . end
        else . end
      )
  ' -n >"$TEMP_SETTINGS"
fi

# T3 Code watches this file and reloads provider state when it changes, so an
# activation that renders the same content must leave it alone. A switch that
# changes nothing then writes nothing and restarts nothing.
if [ ! -f "$SETTINGS" ] || [ "$(<"$TEMP_SETTINGS")" != "$(<"$SETTINGS")" ]; then
  mv -f "$TEMP_SETTINGS" "$SETTINGS"
  chmod 600 "$SETTINGS"
else
  rm -f "$TEMP_SETTINGS"
fi
TEMP_SETTINGS=""
trap - EXIT

# The store is what the provider actually runs on. Write it only when the value
# differs so an unchanged render touches nothing and triggers no restart.
secrets_changed=false
if [ -n "$CLIPROXY_API_KEY" ]; then
  mkdir -p "$SECRETS_DIR"
  for secret in ${managed_secrets[@]+"${managed_secrets[@]}"}; do
    if [ -f "$secret" ] && [ "$(cat "$secret")" = "$CLIPROXY_API_KEY" ]; then
      continue
    fi
    (
      umask 077
      printf '%s' "$CLIPROXY_API_KEY" >"${secret}.tmp"
    )
    mv -f "${secret}.tmp" "$secret"
    secrets_changed=true
  done
fi

# T3 Code reads the instance environment when it loads, so a credential that
# only became resolvable on this pass reaches the providers at the next restart.
# Steady-state activations change nothing and leave running sessions be.
if [ -n "$SYSTEMCTL_BIN" ] && [ -x "$SYSTEMCTL_BIN" ] &&
  { [ "$purged_secret" = true ] || [ "$secrets_changed" = true ]; }; then
  "$SYSTEMCTL_BIN" --user restart t3code.service >/dev/null 2>&1 ||
    echo "Warning: could not restart t3code.service to pick up the CLIProxy credential" >&2
fi
