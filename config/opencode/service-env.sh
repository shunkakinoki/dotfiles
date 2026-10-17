#!/usr/bin/env bash
set -euo pipefail

svc="$HOME/.config/opencode/service.json"
mkdir -p "$(dirname "$svc")"
umask 077
if [ ! -f "$svc" ]; then
  jq -n '{env: {OPENCODE_DB: "opencode-v2.db"}}' >"$svc"
elif [ "$(jq -r '.env.OPENCODE_DB // empty' "$svc")" != "opencode-v2.db" ]; then
  tmp="$(mktemp "$svc.XXXXXX")"
  jq '.env.OPENCODE_DB = "opencode-v2.db"' "$svc" >"$tmp"
  mv "$tmp" "$svc"
fi
