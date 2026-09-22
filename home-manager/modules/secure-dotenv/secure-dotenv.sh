#!/usr/bin/env bash
# Command placeholders are substituted by pkgs.replaceVars.
set -euo pipefail

HOME_DIR="$1"
SCAN_TIMEOUT_SECONDS="${SECURE_DOTENV_SCAN_TIMEOUT_SECONDS:-10}"

# Cache and runtime trees cannot contain source dotenv files and can contain
# millions of entries. Scanning them has stalled Home Manager activation and
# saturated Kyber's root disk. Repository build artifacts are pruned for the
# same reason. The timeout is a final fail-safe for slow or remote filesystems.
# Directories this user cannot traverse (root services write 0700 log
# directories under home) are pruned: descending into them makes find exit
# non-zero, and pipefail turns that into an activation failure.
set +e
@timeout@ --signal=TERM --kill-after=1s "${SCAN_TIMEOUT_SECONDS}s" \
  @nice@ -n 19 \
  @find@ "${HOME_DIR}" \
  -maxdepth 4 \
  \( \
  -path "${HOME_DIR}/Library" -o \
  -path "${HOME_DIR}/.bun" -o \
  -path "${HOME_DIR}/.cache" -o \
  -path "${HOME_DIR}/.cass" -o \
  -path "${HOME_DIR}/.herdr" -o \
  -path "${HOME_DIR}/.local" -o \
  -path "${HOME_DIR}/.npm" \
  \) -prune -o \
  -type d \( \
  -name .git -o \
  -name .next -o \
  -name .turbo -o \
  -name dist -o \
  -name node_modules -o \
  -name target \
  \) -prune -o \
  -type d \( ! -readable -o ! -executable \) -prune -o \
  \( -name '.env' -o -name '.env.*' -o -name '*.env' \) -print |
  while IFS= read -r f; do
    if [ -f "$f" ] && [ ! -L "$f" ]; then
      current=$(@stat@ -c '%a' "$f")
      if [ "$current" != "600" ]; then
        chmod 600 "$f"
      fi
    fi
  done
statuses=("${PIPESTATUS[@]}")
set -e

case "${statuses[0]}" in
0) ;;
124 | 137 | 143)
  echo "Warning: dotenv permission scan exceeded ${SCAN_TIMEOUT_SECONDS}s; remaining paths were skipped" >&2
  ;;
*) exit "${statuses[0]}" ;;
esac

if [ "${statuses[1]}" -ne 0 ]; then
  exit "${statuses[1]}"
fi
