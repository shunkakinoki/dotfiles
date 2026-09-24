#!/usr/bin/env bash
# List, open, and steer Reasonix threads on the durable serve worker.
#
# The worker publishes its bound loopback port and token under
# ~/.local/state/reasonix, so this client never hardcodes either.
set -euo pipefail

STATE_DIR="${REASONIX_WORKER_STATE_DIR:-${HOME}/.local/state/reasonix}"
PORT_FILE="${STATE_DIR}/port"
TOKEN_FILE="${STATE_DIR}/token"
COOKIE_JAR="${STATE_DIR}/cookie"

usage() {
  cat >&2 <<'USAGE'
usage: reasonix-threads <command> [args]

  status                 show worker status as JSON
  list                   list every resident thread
  open <sessionId>       switch the worker's foreground thread to <sessionId>
  new                    start a new thread and make it current
  send <sessionId> <msg>  select <sessionId>, then queue <msg> on it
  steer <sessionId> <msg> steer <msg> into <sessionId>'s running turn
  tail                   stream the worker's event log (SSE)
USAGE
  return 2
}

[ "$#" -ge 1 ] || usage
command=$1
shift

[ -r "$PORT_FILE" ] || {
  echo "reasonix-threads: no worker port at $PORT_FILE (is reasonix-server running?)" >&2
  exit 1
}
[ -r "$TOKEN_FILE" ] || {
  echo "reasonix-threads: no worker token at $TOKEN_FILE" >&2
  exit 1
}

base="http://$(cat "$PORT_FILE")"

# The worker authenticates with a token query that exchanges for an HttpOnly
# cookie; keep the jar so subsequent calls stay authenticated.
auth() {
  curl -sS -c "$COOKIE_JAR" -b "$COOKIE_JAR" -o /dev/null "${base}/status?token=$(cat "$TOKEN_FILE")"
}

api() {
  local method=$1 path=$2
  shift 2
  auth
  curl -sS -c "$COOKIE_JAR" -b "$COOKIE_JAR" -X "$method" "$@" "${base}${path}"
}

# Encode one JSON string. Every call that carries user text goes through this so
# quoting and escapes stay correct.
json_str() {
  printf '%s' "$1" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))'
}

# The queue API addresses a thread by sessionPath; /resume uses sessionId.
session_path() {
  echo "session-id:$1"
}

case "$command" in
status)
  api GET /status
  ;;
list)
  api GET /sessions
  ;;
open)
  [ "$#" -ge 1 ] || usage
  # /resume selects by sessionId; only the inbox queue uses sessionPath.
  api POST /resume -H 'Content-Type: application/json' -d "{\"sessionId\":$(json_str "$1")}"
  ;;
new)
  api POST /new -H 'Content-Type: application/json' -d '{}'
  ;;
send)
  [ "$#" -ge 2 ] || usage
  session_id=$1
  shift
  # /inbox/items has no sessionPath field, so it queues to whichever thread is
  # foreground. /inbox/queue only exposes steer/move/delete kinds, none of which
  # enqueue fresh work. So select the target thread first, then enqueue: the
  # worker has exactly one foreground slot, and this makes the addressing
  # explicit rather than silently landing on the wrong thread.
  api POST /resume -H 'Content-Type: application/json' -d "{\"sessionId\":$(json_str "$session_id")}" >/dev/null
  api POST /inbox/items -H 'Content-Type: application/json' \
    -d "$(printf '{"input":%s,"intent":"followup","idempotencyKey":%s}' \
      "$(json_str "$*")" \
      "$(json_str "send-$(date +%s%N)")")"
  ;;
steer)
  [ "$#" -ge 2 ] || usage
  session_id=$1
  shift
  # A steer targets a running turn, so the turnId is required.
  turn_id=$(api GET /runtime-states |
    python3 -c 'import json,sys
d=json.load(sys.stdin)
sid=sys.argv[1]
for s in d.get("sessions",[]):
    if s.get("state",{}).get("sessionId")==sid:
        print(s["state"].get("turnId",""))
        break' "$session_id")
  [ -n "$turn_id" ] || {
    echo "reasonix-threads: thread $session_id has no running turn to steer" >&2
    exit 1
  }
  api POST /inbox/queue -H 'Content-Type: application/json' \
    -d "$(printf '{"sessionPath":%s,"request":{"kind":"enqueue_steer","turnId":%s,"idempotencyKey":%s,"text":%s}}' \
      "$(json_str "$(session_path "$session_id")")" \
      "$(json_str "$turn_id")" \
      "$(json_str "steer-$(date +%s%N)")" \
      "$(json_str "$*")")"
  ;;
tail)
  auth
  curl -sS -N -b "$COOKIE_JAR" "${base}/events"
  ;;
*)
  usage
  ;;
esac
