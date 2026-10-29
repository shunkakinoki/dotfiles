#!/usr/bin/env bash
# Start hyprlock outside Home Manager's managed unit set so activation cannot
# restart an active locker and orphan Hyprland's secure session lock.
set -euo pipefail

if systemctl --user is-active --quiet hyprlock.service; then
  exit 0
fi

HYPRLOCK="$(command -v hyprlock)"

if systemd-run \
  --user \
  --quiet \
  --collect \
  --unit=hyprlock.service \
  --property='Description=Hyprland screen locker' \
  --property=PartOf=graphical-session.target \
  --property=Restart=on-failure \
  --property=RestartSec=1s \
  --property=StartLimitIntervalSec=30s \
  --property=StartLimitBurst=3 \
  --property=UnsetEnvironment=LD_LIBRARY_PATH \
  "$HYPRLOCK"; then
  exit 0
fi

# Treat a concurrent lock request as success if it won the unit creation race.
systemctl --user is-active --quiet hyprlock.service
