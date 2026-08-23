#!/usr/bin/env bash
set -euo pipefail

STATE_DIR="${HOME}/.dsh"
SETTINGS_FILE="${STATE_DIR}/settings.yaml"
TEMPLATE="@template@"

mkdir -p "$STATE_DIR"

if [ -f "$SETTINGS_FILE" ]; then
  if ! @yq@ -y '.' "$SETTINGS_FILE" >/dev/null 2>&1; then
    echo "Warning: DSH settings are malformed, leaving them unchanged: $SETTINGS_FILE" >&2
    exit 0
  fi

  tmp="$(mktemp "${STATE_DIR}/.settings.yaml.XXXXXX")"
  trap 'rm -f "$tmp"' EXIT
  @yq@ -y -s '.[0] * .[1]' "$SETTINGS_FILE" "$TEMPLATE" >"$tmp"
else
  tmp="$(mktemp "${STATE_DIR}/.settings.yaml.XXXXXX")"
  trap 'rm -f "$tmp"' EXIT
  cp "$TEMPLATE" "$tmp"
fi

chmod 600 "$tmp"
mv -f "$tmp" "$SETTINGS_FILE"
trap - EXIT
echo "Hydrated DSH settings at $SETTINGS_FILE" >&2
