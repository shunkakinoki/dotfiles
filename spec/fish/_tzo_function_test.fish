set fn (status dirname)/../../home-manager/programs/fish/functions
source $fn/_tzo_function.fish

set call_log (mktemp)

function tmux
    echo $argv >> $call_log
    if test "$argv[1]" = has-session
        return 1
    end
end

# Test: not inside Zellij
set -e ZELLIJ
set -e ZELLIJ_PANE_ID
_tzo_function 2>/dev/null
@test "missing ZELLIJ returns 1" $status -eq 1

# Test: inside Zellij but tab name lookup fails
set -gx ZELLIJ 0
function zellij
    return 1
end
_tzo_function 2>/dev/null
@test "missing tab name returns 1" $status -eq 1

# Test: creates new session
function zellij
    echo 'tab name="my-tab" focus=true {'
end
_tzo_function

@test "checks for existing session" (grep -c "has-session -t my-tab" $call_log) -ge 1
@test "creates new session with tab name" (grep -c "new-session -s my-tab" $call_log) -ge 1

# Test: attaches to existing session
echo -n > $call_log
function tmux
    echo $argv >> $call_log
    if test "$argv[1]" = has-session
        return 0
    end
end

_tzo_function

@test "attaches to existing session" (grep -c "attach-session -t my-tab" $call_log) -ge 1

rm -f $call_log
