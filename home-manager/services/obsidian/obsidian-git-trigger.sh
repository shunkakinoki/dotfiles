#!/usr/bin/env bash
# Trigger obsidian-git's commitAndSync via CDP.
#
# The Electron renderer's setTimeout doesn't fire under headless xvfb
# (futex_wait_queue blocks the event loop pump), but CDP messages use
# IPC and bypass the stuck loop. We trigger the backup and keep the
# websocket open with ping-interval for 15s to pump the event loop
# while git operations complete through the obsidian-git plugin.

CDP="http://localhost:9222"

WS_URL=$(@curl@/bin/curl -sf "$CDP/json" | @jq@/bin/jq -r '.[0].webSocketDebuggerUrl // empty')
[ -z "$WS_URL" ] && exit 0

# Send trigger, then keep stdin open for 15s so websocat stays alive.
# The --ping-interval sends websocket pings that pump the Electron
# event loop, allowing the obsidian-git promise queue to execute.
{
  echo '{"id":1,"method":"Runtime.evaluate","params":{"expression":"app.plugins.plugins['"'"'obsidian-git'"'"']?.automaticsManager?.doAutoCommitAndSync()"}}'
  sleep 15
} | @websocat@/bin/websocat --ping-interval 1 "$WS_URL" >/dev/null 2>&1 || true
