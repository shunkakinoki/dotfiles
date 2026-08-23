#!/usr/bin/env bash
# @launchctl@, @printer@ and @keys@ are substituted by pkgs.replaceVars.
# GUI apps (CodexBar and friends) are started by launchd, not by a shell, so they
# never see the .env values that _hm_load_env_file exports into fish/bash/zsh.
# `launchctl setenv` puts them in the GUI session; apps pick them up on next launch.
set -euo pipefail

LAUNCHCTL="@launchctl@"
PRINTER="@printer@"
KEYS="@keys@"

exported=""
while IFS= read -r assignment; do
  key="${assignment%%=*}"
  case " $KEYS " in
  *" $key "*) ;;
  *) continue ;;
  esac

  value="${assignment#*=}"
  [ -n "$value" ] || continue

  "$LAUNCHCTL" setenv "$key" "$value"
  exported="$exported $key"
  echo "Exported $key to the GUI session"
done <<EOF
$(sh "$PRINTER")
EOF

for key in $KEYS; do
  case " $exported " in
  *" $key "*) ;;
  *) echo "Warning: $key is unset in .env, skipping GUI environment export" >&2 ;;
  esac
done
