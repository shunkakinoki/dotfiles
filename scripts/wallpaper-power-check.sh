#!/usr/bin/env bash
# Pause/resume linux-wallpaperengine based on AC power state.
# SIGSTOP freezes on last frame (zero CPU/GPU), SIGCONT resumes animation.
# @ac_supply_path@, @systemctl@, @kill@ are substituted by pkgs.replaceVars.
set -euo pipefail

AC_ONLINE="$(cat "@ac_supply_path@")"
PID="$(@systemctl@ --user show -p MainPID --value linux-wallpaperengine.service)"

if [ -z "$PID" ] || [ "$PID" = "0" ]; then
  exit 0
fi

if [ "$AC_ONLINE" = "0" ]; then
  @kill@ -STOP "$PID" 2>/dev/null || true
else
  @kill@ -CONT "$PID" 2>/dev/null || true
fi
