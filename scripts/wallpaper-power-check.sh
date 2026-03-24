#!/usr/bin/env bash
# Monitor AC power state and pause/resume linux-wallpaperengine accordingly.
# SIGSTOP freezes on last frame (zero CPU/GPU), SIGCONT resumes animation.
# @ac_supply_path@, @systemctl@, @kill@, @sleep@ are substituted by pkgs.replaceVars.
set -euo pipefail

AC_PATH="@ac_supply_path@"
LAST_STATE=""

get_pid() {
  @systemctl@ --user show -p MainPID --value linux-wallpaperengine.service 2>/dev/null || echo "0"
}

apply_state() {
  local ac_online="$1"
  local pid
  pid="$(get_pid)"

  if [ -z "$pid" ] || [ "$pid" = "0" ]; then
    return
  fi

  if [ "$ac_online" = "0" ]; then
    @kill@ -STOP "$pid" 2>/dev/null || true
  else
    @kill@ -CONT "$pid" 2>/dev/null || true
  fi
}

# Let wallpaper engine render its first frame before potentially stopping it
@sleep@ 30

while true; do
  CURRENT_STATE="$(cat "$AC_PATH" 2>/dev/null || echo "")"

  if [ -n "$CURRENT_STATE" ] && [ "$CURRENT_STATE" != "$LAST_STATE" ]; then
    apply_state "$CURRENT_STATE"
    LAST_STATE="$CURRENT_STATE"
  fi

  @sleep@ 5
done
