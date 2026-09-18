#!/usr/bin/env bash
# Feed agent-hook events to the RoboRev daemon running on this host.
# The daemon only accepts registrations that name the agent profile and
# carry its ownership marker; anything else is rejected as outdated.
set -euo pipefail

ROBOREV_BIN="${HOME}/.local/bin/roborev"
AGENT="${1:?agent profile (claude, codex, droid, ...) is required}"

if [ ! -x "$ROBOREV_BIN" ]; then
  exit 0
fi

exec "$ROBOREV_BIN" --server "127.0.0.1:7373" agent-hook run \
  --agent "$AGENT" --source=roborev-agent-hook
