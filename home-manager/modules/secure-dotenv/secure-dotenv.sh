#!/usr/bin/env bash
# @find@ and @stat@ are substituted by pkgs.replaceVars.
set -euo pipefail

HOME_DIR="$1"

@find@ "${HOME_DIR}" \
  -maxdepth 4 \
  \( -name '.env' -o -name '.env.*' -o -name '*.env' \) \
  2>/dev/null | while IFS= read -r f; do
  if [ -f "$f" ] && [ ! -L "$f" ]; then
    current=$(@stat@ -c '%a' "$f")
    if [ "$current" != "600" ]; then
      chmod 600 "$f"
    fi
  fi
done
