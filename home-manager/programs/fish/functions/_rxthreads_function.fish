function _rxthreads_function --description "List, open, and steer Reasonix worker threads"
    set -l state_dir "$HOME/.local/state/reasonix"
    set -l port_file "$state_dir/port"
    set -l token_file "$state_dir/token"
    set -l jar "$state_dir/cookie"

    if not test -r "$port_file"
        echo "rxthreads: no worker port at $port_file (is reasonix-server running?)" >&2
        return 1
    end
    if not test -r "$token_file"
        echo "rxthreads: no worker token at $token_file" >&2
        return 1
    end

    set -l base "http://$(cat "$port_file")"

    # The worker exchanges a token query for an HttpOnly cookie; keep the jar so
    # later calls stay authenticated.
    curl -sS -c "$jar" -b "$jar" -o /dev/null "$base/status?token=$(cat "$token_file")"

    # JSON-encode one string. Every call that carries text goes through this so
    # quoting and escapes stay correct.
    function __rx_json --no-scope-shadowing
        printf '%s' "$argv[1]" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))'
    end

    function __rx_api --no-scope-shadowing
        set -l method $argv[1]
        set -l path $argv[2]
        curl -sS -c "$jar" -b "$jar" -X "$method" $argv[3..-1] "$base$path"
    end

    # The queue API addresses a thread by sessionPath; /resume reads sessionId.
    function __rx_session_path --no-scope-shadowing
        echo "session-id:$argv[1]"
    end

    function __rx_usage --no-scope-shadowing
        printf '%s\n' \
            'usage: rxthreads <command> [args]' \
            '' \
            '  status                    show worker status as JSON' \
            '  list                      list every resident thread' \
            '  current                   print the foreground session id' \
            '  open <sessionId>          make <sessionId> the foreground thread' \
            '  new                        start a thread and make it current' \
            '  send <sessionId> <msg>    select <sessionId>, then queue <msg>' \
            '  steer <sessionId> <msg>   steer <msg> into a running turn' \
            '  tail                      stream the event log (SSE)' >&2
    end

    set -l command $argv[1]
    set -l rest $argv[2..-1]

    switch "$command"
        case status
            __rx_api GET /status
        case list
            __rx_api GET /sessions
        case current
            __rx_api GET /sessions | python3 -c '
import json, sys
for row in json.load(sys.stdin):
    if row.get("current"):
        print(row["sessionId"])
        break
'
        case open
            test (count $rest) -ge 1; or __rx_usage; or return 2
            __rx_api POST /resume -H 'Content-Type: application/json' \
                -d "{\"sessionId\":$(__rx_json "$rest[1]")}"
        case new
            __rx_api POST /new -H 'Content-Type: application/json' -d '{}'
            # /new answers 204 with no body, so surface the new foreground id.
            __rx_api GET /sessions | python3 -c '
import json, sys
for row in json.load(sys.stdin):
    if row.get("current"):
        print(row["sessionId"])
        break
'
        case send
            test (count $rest) -ge 2; or __rx_usage; or return 2
            set -l session_id $rest[1]
            set -l text (string join ' ' $rest[2..-1])
            # /inbox/items has no sessionPath field, so it queues to whichever
            # thread is foreground. Select the target first.
            __rx_api POST /resume -H 'Content-Type: application/json' \
                -d "{\"sessionId\":$(__rx_json "$session_id")}" >/dev/null
            __rx_api POST /inbox/items -H 'Content-Type: application/json' \
                -d "{\"input\":$(__rx_json "$text"),\"intent\":\"followup\",\"idempotencyKey\":$(__rx_json "send-"(date +%s%N))}"
        case steer
            test (count $rest) -ge 2; or __rx_usage; or return 2
            set -l session_id $rest[1]
            set -l text (string join ' ' $rest[2..-1])
            # A steer targets a running turn, so the turnId is required.
            set -l turn_id (__rx_api GET /runtime-states | python3 -c '
import json, sys
sid = sys.argv[1]
for row in json.load(sys.stdin).get("sessions", []):
    state = row.get("state", {})
    if state.get("sessionId") == sid:
        print(state.get("turnId", ""))
        break
' "$session_id")
            if test -z "$turn_id"
                echo "rxthreads: thread $session_id has no running turn to steer" >&2
                return 1
            end
            __rx_api POST /inbox/queue -H 'Content-Type: application/json' \
                -d "{\"sessionPath\":$(__rx_json (__rx_session_path "$session_id")),\"request\":{\"kind\":\"enqueue_steer\",\"turnId\":$(__rx_json "$turn_id"),\"idempotencyKey\":$(__rx_json "steer-"(date +%s%N)),\"text\":$(__rx_json "$text")}}"
        case tail
            curl -sS -N -b "$jar" "$base/events"
        case '' -h --help help
            __rx_usage
            return 2
        case '*'
            __rx_usage
            return 2
    end
end
