set fn (status dirname)/../../home-manager/programs/fish/functions
source $fn/_two_function.fish

# ── no resurrect, no work session → tmuxinator start work ─
set log (mktemp)
function tmux
    if test "$argv[1]" = list-keys; echo ""; return; end
    if test "$argv[1]" = has-session; return 1; end
end
function tmuxinator; echo $argv >> $log; end

_two_function

@test "missing work session starts via tmuxinator" (grep -c "start work" $log) -ge 1

# ── session exists, outside tmux → attach ────────────────
set log2 (mktemp)
set -e TMUX
function tmux
    if test "$argv[1]" = list-keys; echo ""; return; end
    if test "$argv[1]" = has-session; return 0; end
    echo $argv >> $log2
end

_two_function

@test "existing work session attaches" (grep -c "attach-session -t work" $log2) -ge 1

rm -f $log $log2
