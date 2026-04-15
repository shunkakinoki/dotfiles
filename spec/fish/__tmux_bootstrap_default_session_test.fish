set fn (status dirname)/../../home-manager/programs/fish/functions
source $fn/__tmux_bootstrap_default_session.fish

# ── primary session bootstrap ─────────────────────────────
set log_primary (mktemp)
function tmux
    echo $argv >> $log_primary
end

__tmux_bootstrap_default_session primary

@test "primary bootstrap starts btop session" (grep -c "new-session -d -s primary -n btop" $log_primary) -ge 1
@test "primary bootstrap creates dotfiles window" (grep -Ec "new-window -c .*dotfiles -t primary:1 -n dotfiles" $log_primary) -ge 1
@test "primary bootstrap creates session-specific window" (grep -c "new-window -t primary:2 -n primary" $log_primary) -ge 1

# ── work session bootstrap ────────────────────────────────
set log_work (mktemp)
function tmux
    echo $argv >> $log_work
end

__tmux_bootstrap_default_session work

@test "work bootstrap starts editor session" (grep -c "new-session -d -s work -n editor" $log_work) -ge 1
@test "work bootstrap opens shell window" (grep -c "new-window -t work:1 -n shell" $log_work) -ge 1
@test "work bootstrap opens work window" (grep -c "new-window -t work:2 -n work" $log_work) -ge 1

# ── unknown session rejected ──────────────────────────────
set log_unknown (mktemp)
function tmux
    echo $argv >> $log_unknown
end

__tmux_bootstrap_default_session unknown >/dev/null 2>/dev/null
set unknown_status $status

@test "unknown session returns failure" test $unknown_status -ne 0
@test "unknown session does not touch tmux" test ! -s $log_unknown

rm -f $log_primary $log_work $log_unknown
