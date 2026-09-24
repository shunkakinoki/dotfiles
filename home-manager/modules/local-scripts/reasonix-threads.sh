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
  send <sessionId> <msg> queue <msg> on <sessionId> as a follow-up
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

# The queue API addresses a thread by sessionPath, not sessionId.
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
  api POST /resume -H 'Content-Type: application/json' -d "{\"sessionPath\":\"$(session_path "$1")\"}"
  ;;
new)
  api POST /new -H 'Content-Type: application/json' -d '{}'
  ;;
send)
  [ "$#" -ge 2 ] || usage
  session_id=$1
  shift
  api POST /inbox/items -H 'Content-Type: application/json' \
    -d "$(printf '{"input":%s,"intent":"followup","sessionPath":%s}' \
      "$(printf '%s' "$*" | python3 -c 'import json,sys;print(json.dumps(sys.stdin.read()))')" \
      "$(printf '%s' "$(session_path "$session_id")" | python3 -c 'import json,sys;print(json.dumps(sys.stdin.read()))')")"
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
      "$(printf '%s' "$(session_path "$session_id")" | python3 -c 'import json,sys;print(json.dumps(sys.stdin.read()))')" \
      "$(printf '%s' "$turn_id" | python3 -c 'import json,sys;print(json.dumps(sys.stdin.read()))')" \
      "$(printf 'steer-%s' "$(date +%s%N)" | python3 -c 'import json,sys;print(json.dumps(sys.stdin.read()))')" \
      "$(printf '%s' "$*" | python3 -c 'import json,sys;print(json.dumps(sys.stdin.read()))')")"
  ;;
tail)
  auth
  curl -sS -N -b "$COOKIE_JAR" "${base}/events"
  ;;
*)
  usage
  ;;
esac
