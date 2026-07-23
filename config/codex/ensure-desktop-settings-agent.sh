#!/usr/bin/env bash
# Ensure the Home Manager-managed Codex Desktop settings watcher is persistent
# and loaded, even when launchd setup did not register the new agent.
set -euo pipefail

AGENT_LABEL="$1"
SOURCE_PLIST="$2"
LAUNCHCTL_BIN="$3"
INSTALL_BIN="$4"
ID_BIN="$5"

AGENT_DIR="$HOME/Library/LaunchAgents"
AGENT_PLIST="$AGENT_DIR/$AGENT_LABEL.plist"
AGENT_DOMAIN="gui/$("$ID_BIN" -u)"

mkdir -p "$AGENT_DIR"

agent_loaded=false
if "$LAUNCHCTL_BIN" print "$AGENT_DOMAIN/$AGENT_LABEL" >/dev/null 2>&1; then
  agent_loaded=true
fi

# Keep the persisted plist byte-identical to Home Manager's generated source.
if ! cmp -s "$SOURCE_PLIST" "$AGENT_PLIST"; then
  "$INSTALL_BIN" -m 444 "$SOURCE_PLIST" "$AGENT_PLIST"
fi

if [[ $agent_loaded == true ]]; then
  exit 0
fi

if "$LAUNCHCTL_BIN" bootstrap "$AGENT_DOMAIN" "$AGENT_PLIST"; then
  exit 0
fi

# Recover from a stale or malformed destination plist before retrying.
"$LAUNCHCTL_BIN" bootout "$AGENT_DOMAIN/$AGENT_LABEL" >/dev/null 2>&1 || true
"$INSTALL_BIN" -m 444 "$SOURCE_PLIST" "$AGENT_PLIST"
"$LAUNCHCTL_BIN" bootstrap "$AGENT_DOMAIN" "$AGENT_PLIST"
