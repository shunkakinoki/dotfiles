set fn ../../home-manager/programs/fish/functions
source $fn/_tmo_function.fish

# ── session missing → tmuxinator start mobile ─────────────
set log1 (mktemp)
function tmux
    if test "$argv[1]" = has-session; return 1; end
end
function tmuxinator; echo $argv >> $log1; end

_tmo_function

@test "missing session starts via tmuxinator" (grep -c "start mobile" $log1) -ge 1

# ── session exists, outside tmux → attach ────────────────
set log2 (mktemp)
set -e TMUX
function tmux
    if test "$argv[1]" = has-session; return 0; end
    echo $argv >> $log2
end

_tmo_function

@test "existing session attaches" (grep -c "attach-session -t mobile" $log2) -ge 1

rm -f $log1 $log2
