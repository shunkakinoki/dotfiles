set fn (status dirname)/../../home-manager/programs/fish/functions
source $fn/_tmo_function.fish

# ── session missing → bootstrap + attach ──────────────────
set log1 (mktemp)
set -e TMUX
function tmux
    if test "$argv[1]" = has-session
        return 1
    end
    echo $argv >> $log1
end
function tmuxinator; echo tmuxinator $argv >> $log1; end

_tmo_function

@test "missing session bootstraps btop window" (grep -c "new-session -d -s mobile -n btop" $log1) -ge 1
@test "missing session bootstraps dotfiles window" (grep -Ec "new-window -c .*dotfiles -t mobile:1 -n dotfiles" $log1) -ge 1
@test "missing session sets even-horizontal layout" (grep -c "select-layout -t mobile:1 even-horizontal" $log1) -ge 1
@test "missing session attaches after bootstrap" (grep -c "attach-session -t mobile" $log1) -ge 1
@test "missing session bypasses tmuxinator" (grep -c "^tmuxinator " $log1) -eq 0

# ── session missing, inside tmux → bootstrap + switch ──────────
set log_inside (mktemp)
set -gx TMUX /tmp/tmux-mobile-test
function tmux
    if test "$argv[1]" = has-session
        return 1
    end
    echo $argv >> $log_inside
end
function tmuxinator; echo tmuxinator $argv >> $log_inside; end

_tmo_function

@test "missing session inside tmux bootstraps session" (grep -c "new-session -d -s mobile -n btop" $log_inside) -ge 1
@test "missing session inside tmux switches client" (grep -c "switch-client -t mobile" $log_inside) -ge 1
@test "missing session inside tmux bypasses tmuxinator" (grep -c "^tmuxinator " $log_inside) -eq 0

# ── session exists, outside tmux → attach ────────────────
set log2 (mktemp)
set -e TMUX
function tmux
    if test "$argv[1]" = has-session; return 0; end
    echo $argv >> $log2
end

_tmo_function

@test "existing session attaches" (grep -c "attach-session -t mobile" $log2) -ge 1

rm -f $log1 $log_inside $log2
