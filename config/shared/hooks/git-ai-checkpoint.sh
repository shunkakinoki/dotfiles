#!/usr/bin/env bash
# Shared Write/Edit hook for Claude Code, Cursor, Factory Droid, and Gemini.
# Usage: git-ai-checkpoint.sh <preset>   (hook payload on stdin)
set -uo pipefail

PRESET="${1:?preset required}"
LIMIT="${GIT_AI_CHECKPOINT_TIMEOUT:-15}"

GIT_AI="$(command -v git-ai 2>/dev/null || true)"
[ -n "$GIT_AI" ] || GIT_AI="$HOME/.cargo/bin/git-ai"
[ -x "$GIT_AI" ] || exit 0

# A checkpoint blocked on a busy repository outlives the harness's own hook
# timeout, which signals only the shell it spawned. `timeout` signals the whole
# process group, so the git children go with it. Without it the run would be
# unbounded, so authorship tracking is skipped instead.
TIMEOUT="$(command -v timeout 2>/dev/null || command -v gtimeout 2>/dev/null || true)"
[ -n "$TIMEOUT" ] || exit 0

# A checkpoint otherwise spawns `git-ai flush-logs` without waiting on it. That
# child outlives every timeout here and retries failed uploads for hours while
# holding the flush lock. git-ai skips the spawn when it believes it is already
# the flush worker, and the scheduled maintenance job flushes with a bound.
export GIT_AI_FLUSH_LOGS_WORKER=1

"$TIMEOUT" -k 2 "$LIMIT" "$GIT_AI" checkpoint "$PRESET" --hook-input stdin
STATUS=$?
case "$STATUS" in
124 | 137)
  echo "git-ai checkpoint $PRESET exceeded ${LIMIT}s; skipped" >&2
  exit 0
  ;;
esac
exit "$STATUS"
