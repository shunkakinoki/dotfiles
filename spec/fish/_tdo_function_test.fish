set fn (status dirname)/../../home-manager/programs/fish/functions
source $fn/__tmux_bootstrap_default_session.fish
source $fn/_tdo_function.fish

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

_tdo_function

@test "missing session bootstraps btop window" (grep -c "new-session -d -s desktop -n btop" $log1) -ge 1
@test "missing session bootstraps dotfiles window" (grep -Ec "new-window -c .*dotfiles -t desktop:1 -n dotfiles" $log1) -ge 1
@test "missing session sets even-horizontal layout" (grep -c "select-layout -t desktop:1 even-horizontal" $log1) -ge 1
@test "missing session attaches after bootstrap" (grep -c "attach-session -t desktop" $log1) -ge 1
@test "missing session bypasses tmuxinator" (grep -c "^tmuxinator " $log1) -eq 0

# ── session missing, inside tmux → bootstrap + switch ──────────
set log_inside (mktemp)
set -gx TMUX /tmp/tmux-desktop-test
function tmux
    if test "$argv[1]" = has-session
        return 1
    end
    echo $argv >> $log_inside
end
function tmuxinator; echo tmuxinator $argv >> $log_inside; end

_tdo_function

@test "missing session inside tmux bootstraps session" (grep -c "new-session -d -s desktop -n btop" $log_inside) -ge 1
@test "missing session inside tmux switches client" (grep -c "switch-client -t desktop" $log_inside) -ge 1
@test "missing session inside tmux bypasses tmuxinator" (grep -c "^tmuxinator " $log_inside) -eq 0

# ── session exists, outside tmux → attach ────────────────
set log2 (mktemp)
set -e TMUX
function tmux
    if test "$argv[1]" = has-session; return 0; end
    echo $argv >> $log2
end

_tdo_function

@test "existing session attaches" (grep -c "attach-session -t desktop" $log2) -ge 1

rm -f $log1 $log_inside $log2
