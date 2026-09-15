#!/usr/bin/env bash
# Guard around `traces hook agent <event> --agent <id>`. Every agent adapter
# (native hook configs and the Pi, Hermes, and OpenClaw extensions) goes
# through here so the in-flight accounting sees all uploads of one user.
#
# The traces hook spawns a detached `traces share --trace-id ... --source
# agent_hook` upload on every prompt-submitted, agent-done, and session-end
# event without checking whether one is already running. Each upload rescans
# the shared SQLite trace store, so a busy lane stacks up dozens of uploads of
# the same trace that contend with each other and never finish. This wrapper
# lets at most one upload per trace and a small number per user run at once,
# terminates uploads that have clearly wedged, and otherwise defers to the
# real hook. It always exits 0: telemetry must never block an agent.
# shellcheck disable=SC2329
set -u

# Kyber's managed queue owns the hook and its detached uploader together.
# Other hosts retain the process guard below.
queue="${HOME}/.local/libexec/traces-agent-uploads"
if [ -x "$queue" ]; then
  "$queue" enqueue "$@" || true
  exit 0
fi

event="${1:-}"
shift || true

traces_bin="${TRACES_BIN:-traces}"
command -v "$traces_bin" >/dev/null 2>&1 || exit 0

# A single upload is enough to preserve telemetry and prevents detached
# uploaders from competing for the trace-store lock on developer machines.
MAX_INFLIGHT_UPLOADS="${TRACES_HOOK_MAX_INFLIGHT_UPLOADS:-1}"
STALE_UPLOAD_SECONDS="${TRACES_HOOK_STALE_UPLOAD_SECONDS:-300}"

payload="$(cat)"

run_hook() {
  printf '%s' "$payload" | "$traces_bin" hook agent "$event" "$@" || true
  exit 0
}

case "$event" in
prompt-submitted | agent-done | session-end) ;;
*) run_hook "$@" ;;
esac

trace_id=""
if command -v jq >/dev/null 2>&1; then
  trace_id="$(printf '%s' "$payload" | jq -r '.session_id // .sessionId // empty' 2>/dev/null || true)"
fi

# Hook commands are async and can enter this wrapper concurrently. Without an
# atomic admission lock, every invocation can observe the same empty process
# list before any detached `traces share` is visible, defeating the cap.
STATE_DIR="${TRACES_HOOK_STATE_DIR:-${HOME}/.local/state/traces-agent-hook}"
LOCK_DIR="$STATE_DIR/admission.lock"
LOCK_HELD=0
umask 077

cleanup_lock() {
  if [ "$LOCK_HELD" -eq 1 ]; then
    rm -f "$LOCK_DIR/pid"
    rmdir "$LOCK_DIR" 2>/dev/null || true
  fi
}
trap cleanup_lock EXIT HUP INT TERM

acquire_lock() {
  mkdir -p "$STATE_DIR" 2>/dev/null || return 1
  if mkdir "$LOCK_DIR" 2>/dev/null; then
    printf '%s\n' "$$" >"$LOCK_DIR/pid"
    LOCK_HELD=1
    return 0
  fi

  # Recover only a lock whose owner has definitely exited. The directory
  # creation remains the atomic operation that admits exactly one hook.
  owner="$(cat "$LOCK_DIR/pid" 2>/dev/null || true)"
  if [ -n "$owner" ] && ! kill -0 "$owner" 2>/dev/null; then
    rm -f "$LOCK_DIR/pid"
    rmdir "$LOCK_DIR" 2>/dev/null || true
    if mkdir "$LOCK_DIR" 2>/dev/null; then
      printf '%s\n' "$$" >"$LOCK_DIR/pid"
      LOCK_HELD=1
      return 0
    fi
  fi
  return 1
}

if [ "$event" = "session-end" ]; then
  # Give an in-flight lifecycle hook a short, bounded chance to finish so the
  # final event can still be recorded without allowing indefinite buildup.
  acquired=0
  attempt=0
  while [ "$attempt" -lt 20 ]; do
    if acquire_lock; then
      acquired=1
      break
    fi
    attempt=$((attempt + 1))
    sleep 0.1
  done
  [ "$acquired" -eq 1 ] || exit 0
else
  acquire_lock || exit 0
fi

# One line per hook-triggered upload owned by this user: pid, elapsed seconds,
# trace id. `etime` is the portable elapsed column ([[dd-]hh:]mm:ss).
list_uploads() {
  ps -U "$(id -un)" -o pid=,etime=,args= 2>/dev/null | awk '
    function elapsed_seconds(value, days, fields, count, seconds, i) {
      days = 0
      if (index(value, "-")) {
        split(value, fields, "-")
        days = fields[1]
        value = fields[2]
      }
      count = split(value, fields, ":")
      seconds = 0
      for (i = 1; i <= count; i++) seconds = seconds * 60 + fields[i]
      return days * 86400 + seconds
    }
    /(^|[ \/])traces share / && /--source agent_hook/ && match($0, /--trace-id [^ ]+/) {
      print $1, elapsed_seconds($2), substr($0, RSTART + 11, RLENGTH - 11)
    }'
}

inflight=0
same_trace_running=0
while read -r pid elapsed upload_trace; do
  [ -n "${pid:-}" ] || continue
  if [ "$elapsed" -ge "$STALE_UPLOAD_SECONDS" ]; then
    kill -TERM "$pid" 2>/dev/null || true
    continue
  fi
  if [ -n "$trace_id" ] && [ "$upload_trace" = "$trace_id" ]; then
    if [ "$event" = "session-end" ]; then
      # The final upload supersedes the in-flight one for the same trace.
      kill -TERM "$pid" 2>/dev/null || true
      continue
    fi
    same_trace_running=1
  fi
  inflight=$((inflight + 1))
done <<EOF
$(list_uploads)
EOF

if [ "$event" != "session-end" ]; then
  if [ "$same_trace_running" -eq 1 ] || [ "$inflight" -ge "$MAX_INFLIGHT_UPLOADS" ]; then
    # The next lifecycle event retries; nothing is lost because the upload
    # that is already running (or the session-end upload) carries the trace.
    exit 0
  fi
fi

run_hook "$@"
