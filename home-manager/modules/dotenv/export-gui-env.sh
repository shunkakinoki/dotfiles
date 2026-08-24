#!/usr/bin/env bash
# @launchctl@ and @printer@ are substituted by pkgs.replaceVars.
# GUI apps (CodexBar and friends) are started by launchd, not by a shell, so they
# never see the .env values that _hm_load_env_file exports into fish/bash/zsh.
# `launchctl setenv` puts every parsed assignment in the GUI session; apps pick
# them up on next launch. Values are never written to activation output.
set -euo pipefail

LAUNCHCTL="@launchctl@"
PRINTER="@printer@"

while IFS= read -r assignment; do
  [ -n "$assignment" ] || continue
  key="${assignment%%=*}"
  value="${assignment#*=}"

  "$LAUNCHCTL" setenv "$key" "$value"
  echo "Exported $key to the GUI session"
done <<EOF
$(sh "$PRINTER")
EOF
