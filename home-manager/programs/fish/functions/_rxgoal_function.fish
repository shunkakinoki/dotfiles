function _rxgoal_function --description "Arm a Reasonix goal on the serve worker and kick the first autonomous round"
    set -l state_dir "$HOME/.local/state/reasonix"
    set -l port_file "$state_dir/port"
    set -l token_file "$state_dir/token"
    set -l jar "$state_dir/cookie"

    if not test -r "$port_file"
        echo "rxgoal: no worker port at $port_file (is reasonix-server running?)" >&2
        return 1
    end
    if not test -r "$token_file"
        echo "rxgoal: no worker token at $token_file" >&2
        return 1
    end

    set -l base "http://$(cat $port_file)"

    # The worker exchanges a token query for an HttpOnly cookie; keep the jar so
    # every later call stays authenticated.
    curl -sS -c "$jar" -b "$jar" -o /dev/null "$base/status?token=$(cat $token_file)"

    switch "$argv[1]"
        case --clear -c
            curl -sS -b "$jar" -c "$jar" -X POST -H 'Content-Type: application/json' \
                -d '{"goal":""}' "$base/goal" -o /dev/null -w 'cleared HTTP %{http_code}\n'
            return 0

        case '' --status -s
            curl -sS -b "$jar" "$base/status" | python3 -c '
import json, sys
d = json.load(sys.stdin)
gv = d.get("goalView") or {}
goal = d.get("goal") or ""
print("goal:      ", goal if goal else "(none)")
print("status:    ", d.get("goalStatus"))
print("phase:     ", gv.get("phase"))
print("activation:", gv.get("activation"))
print("rounds:    ", gv.get("roundsStarted"), "/", gv.get("maxGoalRounds") or "unlimited")
print("turn busy: ", d.get("cancellable"))
'
            return 0
    end

    # Arming through the HTTP surface persists the goal but does NOT schedule the
    # first round: the driver only kicks on a completed turn. So send a bootstrap
    # turn after arming. That turn carries the armed goal as <active-goal>
    # context, and its TurnDone is what starts the autonomous chain.
    set -l objective "$argv"
    set -l payload (python3 -c 'import json,sys; print(json.dumps({"goal": " ".join(sys.argv[1:])}))' $objective)

    curl -sS -b "$jar" -c "$jar" -X POST -H 'Content-Type: application/json' \
        -d "$payload" "$base/goal" -o /dev/null -w 'armed HTTP %{http_code}\n'
    or return 1

    set -l kick (python3 -c 'import json,sys; print(json.dumps({"input": " ".join(sys.argv[1:])}))' \
        "Begin working the armed goal now. Start with the first concrete step.")

    curl -sS -b "$jar" -c "$jar" -X POST -H 'Content-Type: application/json' \
        -d "$kick" "$base/submit" -o /dev/null -w 'kicked HTTP %{http_code}\n'

    echo "Goal armed and kicked. Watch rounds with: rxgoal"
end
