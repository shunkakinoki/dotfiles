#!/usr/bin/env bash
# @find@ and @stat@ are substituted by pkgs.replaceVars.
set -euo pipefail

HOME_DIR="$1"

# ~/Library is pruned: on macOS, opening app group containers blocks forever
# on TCC app-data mediation, hanging activation. Dotenv files live in code
# checkouts, never under Library.
@find@ "${HOME_DIR}" \
  -maxdepth 4 \
  -path "${HOME_DIR}/Library" -prune -o \
  \( -name '.env' -o -name '.env.*' -o -name '*.env' \) -print \
  2>/dev/null | while IFS= read -r f; do
  if [ -f "$f" ] && [ ! -L "$f" ]; then
    current=$(@stat@ -c '%a' "$f")
    if [ "$current" != "600" ]; then
      chmod 600 "$f"
    fi
  fi
done
