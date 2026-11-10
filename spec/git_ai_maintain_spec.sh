#!/usr/bin/env bash
# shellcheck disable=SC2016,SC2119,SC2120,SC2329

Describe 'config/git-ai/maintain.sh'
SCRIPT="$PWD/config/git-ai/maintain.sh"

setup() {
  WORK=$(mktemp -d)
  STATE="$WORK/state"
  FAKE_BIN="$WORK/bin"
  mkdir -p "$STATE/internal/logs" "$FAKE_BIN"
  cat >"$FAKE_BIN/git-ai" <<'FAKE'
#!/usr/bin/env bash
echo "$*" >>"$FAKE_GIT_AI_CALLS"
[ -z "${FAKE_GIT_AI_SLEEP:-}" ] || sleep "$FAKE_GIT_AI_SLEEP"
FAKE
  chmod +x "$FAKE_BIN/git-ai"
  FAKE_GIT_AI_CALLS="$WORK/calls"
  export FAKE_GIT_AI_CALLS
  touch "$STATE/internal/logs/1.log"
  touch -t 202001010000 "$STATE/internal/logs/2.log" "$STATE/internal/logs/keep.txt"
}

cleanup() {
  rm -rf "$WORK"
}

Before 'setup'
After 'cleanup'

run_maintain() {
  env PATH="$FAKE_BIN:$PATH" GIT_AI_HOME="$STATE" "$@" bash "$SCRIPT"
}

It 'flushes logs and prunes only stale log files'
When call run_maintain
The status should be success
The contents of file "$FAKE_GIT_AI_CALLS" should equal 'flush-logs'
The path "$STATE/internal/logs/1.log" should be exist
The path "$STATE/internal/logs/2.log" should not be exist
The path "$STATE/internal/logs/keep.txt" should be exist
End

It 'stops a flush that exceeds the limit'
When call run_maintain FAKE_GIT_AI_SLEEP=30 GIT_AI_FLUSH_TIMEOUT=1
The status should be success
The path "$STATE/internal/logs/2.log" should not be exist
End

It 'truncates the write-ahead log'
wal_bytes() {
  # Killing the writer mirrors git-ai exiting without closing its connection.
  {
    echo 'PRAGMA journal_mode=WAL; CREATE TABLE t(x); INSERT INTO t VALUES (1);'
    sleep 3
  } | sqlite3 "$STATE/internal/db" >/dev/null 2>&1 &
  writer=$!
  for _ in 1 2 3 4 5 6 7 8 9 10; do
    [ -s "$STATE/internal/db-wal" ] && break
    sleep 0.2
  done
  kill -9 "$writer"
  [ -s "$STATE/internal/db-wal" ] || return 1
  run_maintain >/dev/null
  [ -s "$STATE/internal/db-wal" ] || echo truncated
}
Skip if 'sqlite3 is missing' test -z "$(command -v sqlite3)"
When call wal_bytes
The status should be success
The output should equal truncated
End

It 'does nothing without git-ai state'
When call run_maintain GIT_AI_HOME="$WORK/missing"
The status should be success
The path "$FAKE_GIT_AI_CALLS" should not be exist
End
End
