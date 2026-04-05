set fn (status dirname)/../../home-manager/programs/fish/functions
source $fn/_tzo_function.fish

set call_log (mktemp)

function tmux
    echo $argv >> $call_log
    if test "$argv[1]" = has-session
        return 1
    end
end

# Test: missing ZELLIJ_TAB_NAME
set -e ZELLIJ_TAB_NAME
_tzo_function 2>/dev/null
@test "missing tab name returns 1" $status -eq 1

# Test: creates new session
set -gx ZELLIJ_TAB_NAME "my-tab"
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
