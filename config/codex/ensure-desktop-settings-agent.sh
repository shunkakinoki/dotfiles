#!/usr/bin/env bash
# Ensure the Home Manager-managed Codex Desktop settings watcher is persistent
# and loaded, even when launchd setup did not register the new agent.
set -euo pipefail

AGENT_LABEL="$1"
FALLBACK_PLIST="$2"
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

# A loaded service without its plist would disappear on the next login.
if [[ ! -s $AGENT_PLIST ]]; then
  "$INSTALL_BIN" -m 444 "$FALLBACK_PLIST" "$AGENT_PLIST"
fi

if [[ $agent_loaded == true ]]; then
  exit 0
fi

if "$LAUNCHCTL_BIN" bootstrap "$AGENT_DOMAIN" "$AGENT_PLIST"; then
  exit 0
fi

# Recover from a stale or malformed destination plist before retrying.
"$LAUNCHCTL_BIN" bootout "$AGENT_DOMAIN/$AGENT_LABEL" >/dev/null 2>&1 || true
"$INSTALL_BIN" -m 444 "$FALLBACK_PLIST" "$AGENT_PLIST"
"$LAUNCHCTL_BIN" bootstrap "$AGENT_DOMAIN" "$AGENT_PLIST"
