#!/usr/bin/env bash
# shellcheck disable=SC2016
# Copy Codex config files and synchronize managed Desktop settings.
# Usage: activate.sh <config_toml> <hooks_json> <desktop_settings_json> <jq_bin> <sync_script> <profiles_dir> [env_printer]
set -euo pipefail
CONFIG_TOML="$1"
HOOKS_JSON="$2"
DESKTOP_SETTINGS_JSON="$3"
JQ_BIN="$4"
SYNC_SCRIPT="$5"
PROFILES_DIR="$6"
ENV_PRINTER="${7:-}"
HERDR_MARKER='bun __DOTFILES_HERDR_SOURCE_CHECKOUT__/scripts/herdr-lane.ts hook'

herdr_source_checkout="${HERDR_SOURCE_CHECKOUT:-}"
if [ -n "$ENV_PRINTER" ]; then
  if ! env_assignments="$(HOME="$HOME" sh "$ENV_PRINTER")"; then
    echo "error: failed to read the private dotfiles environment" >&2
    exit 1
  fi
  while IFS= read -r assignment; do
    case "$assignment" in
    HERDR_SOURCE_CHECKOUT=*) herdr_source_checkout="${assignment#*=}" ;;
    esac
  done <<<"$env_assignments"
fi

herdr_configured=false
herdr_command=""
if [ -n "$herdr_source_checkout" ]; then
  case "$herdr_source_checkout" in
  /*) ;;
  *)
    echo "error: HERDR_SOURCE_CHECKOUT must be an absolute path" >&2
    exit 1
    ;;
  esac
  if [ ! -f "$herdr_source_checkout/scripts/herdr-lane.ts" ]; then
    echo "error: HERDR_SOURCE_CHECKOUT does not contain scripts/herdr-lane.ts" >&2
    exit 1
  fi
  herdr_script="$herdr_source_checkout/scripts/herdr-lane.ts"
  herdr_shell_path="$($JQ_BIN -nr --arg path "$herdr_script" '$path | @sh')"
  herdr_command="bun ${herdr_shell_path} hook"
  herdr_configured=true
fi

mkdir -p ~/.codex/hooks
hooks_tmp="$HOME/.codex/hooks.json.tmp.$$"
trap 'rm -f "$hooks_tmp"' EXIT

"$JQ_BIN" \
  --arg marker "$HERDR_MARKER" \
  --arg command "$herdr_command" \
  --argjson configured "$herdr_configured" \
  '
    def render_event:
      map(
        .hooks |= map(
          if (.command? == $marker) then
            if $configured then .command = $command else empty end
          else . end
        )
        | select((.hooks | length) > 0)
      );
    .hooks.SessionStart |= render_event
    | .hooks.UserPromptSubmit |= render_event
  ' "$HOOKS_JSON" >"$hooks_tmp"
chmod 644 "$hooks_tmp"

for profile in "$PROFILES_DIR"/*.config.toml; do
  destination="$HOME/.codex/$(basename "$profile")"
  cp -f "$profile" "$destination"
  chmod 600 "$destination"
done
cp -f "$CONFIG_TOML" ~/.codex/config.toml
chmod 600 ~/.codex/config.toml
mv -f "$hooks_tmp" ~/.codex/hooks.json

"$SYNC_SCRIPT" "$DESKTOP_SETTINGS_JSON" "$JQ_BIN"
