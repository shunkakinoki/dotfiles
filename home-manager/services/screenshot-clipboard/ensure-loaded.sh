#!/usr/bin/env bash

set -euo pipefail

label=org.nix-community.home.screenshot-clipboard
plist="$HOME/Library/LaunchAgents/$label.plist"
service="gui/$(id -u)/$label"
ready_file="${XDG_STATE_HOME:-$HOME/.local/state}/screenshot-clipboard/ready-pid"

if [[ ! -f $plist ]]; then
  echo "Screenshot clipboard LaunchAgent is missing: $plist; activate Home Manager first" >&2
  exit 1
fi

# KeepAlive restarts an exited process, but cannot re-register an unloaded job.
# Do not unload a healthy watcher: that creates another gap in screenshot copying.
launchctl enable "$service"
if ! launchctl print "$service" >/dev/null 2>&1; then
  rm -f "$ready_file"
  launchctl bootstrap "gui/$(id -u)" "$plist"
fi
launchctl kickstart "$service"

# Successful bootstrap/kickstart only accepts the request. The watcher records
# its own PID after registering kqueue; a PID from launchd alone is not readiness.
for _ in {1..50}; do
  pid=$(launchctl print "$service" | awk '/^[[:space:]]*pid = [1-9][0-9]*/ { print $3 }')
  if [[ -n $pid && -f $ready_file && $(cat "$ready_file") == "$pid" ]]; then
    echo "Screenshot clipboard watcher is running"
    exit 0
  fi
  sleep 0.1
done

echo "Screenshot clipboard watcher did not become ready; check ~/Library/Logs/screenshot-clipboard.error.log" >&2
exit 1
