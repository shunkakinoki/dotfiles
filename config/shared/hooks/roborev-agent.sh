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

# On a detached HEAD the daemon matches every open failed review in the repo
# with one `git merge-base --is-ancestor` each, per tool call, and keeps going
# after the client gives up. With thousands of open CI reviews that saturates
# the daemon and every hook times out, so only branch checkouts are tracked.
# A bare repository has a symbolic HEAD but no checkout, so require a work tree.
if [ "$(git rev-parse --is-inside-work-tree 2>/dev/null)" != true ] ||
  ! git symbolic-ref -q HEAD >/dev/null 2>&1; then
  exit 0
fi

exec "$ROBOREV_BIN" --server "127.0.0.1:7373" agent-hook run \
  --agent "$AGENT" --source=roborev-agent-hook
