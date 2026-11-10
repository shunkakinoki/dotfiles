#!/usr/bin/env bash
# Bounds the state git-ai leaves in ~/.git-ai: flushes queued logs with a time
# limit, truncates the SQLite write-ahead logs, and drops logs no flush cleared.
set -uo pipefail

internal="${GIT_AI_HOME:-$HOME/.git-ai}/internal"
flush_limit="${GIT_AI_FLUSH_TIMEOUT:-300}"
log_days="${GIT_AI_LOG_RETENTION_DAYS:-7}"
[ -d "$internal" ] || exit 0

GIT_AI="$(command -v git-ai 2>/dev/null || true)"
[ -n "$GIT_AI" ] || GIT_AI="$HOME/.cargo/bin/git-ai"
TIMEOUT="$(command -v timeout 2>/dev/null || command -v gtimeout 2>/dev/null || true)"

# An unbounded flush sleeps a minute per failed upload across every queued log.
if [ -x "$GIT_AI" ] && [ -n "$TIMEOUT" ]; then
  "$TIMEOUT" -k 5 "$flush_limit" "$GIT_AI" flush-logs >/dev/null 2>&1 || true
fi

# git-ai exits without closing its connections, so the WAL is never truncated
# and keeps its largest size. A busy database is left for the next run.
if command -v sqlite3 >/dev/null 2>&1; then
  for db in "$internal/db" "$internal/metrics-db"; do
    [ -f "$db" ] || continue
    sqlite3 "$db" 'PRAGMA busy_timeout=5000; PRAGMA wal_checkpoint(TRUNCATE);' >/dev/null 2>&1 || true
  done
fi

# git-ai deletes a log only when a flush run completes, and a flush cut short
# by the limit above deletes none.
if [ -d "$internal/logs" ]; then
  find "$internal/logs" -maxdepth 1 -type f -name '*.log' -mtime +"$log_days" -delete
fi
