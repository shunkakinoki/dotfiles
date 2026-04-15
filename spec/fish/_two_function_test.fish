set fn (status dirname)/../../home-manager/programs/fish/functions
source $fn/_two_function.fish

# ── restore script brings back work session ───────────────
set log_restore (mktemp)
set -e TMUX
set -g _two_has_work 0
set -g _two_has_server 0
function tmux
    switch "$argv[1]"
        case has-session
            if test "$argv[3]" = work -a $_two_has_work -eq 1
                return 0
            end
            return 1
        case list-sessions
            if test $_two_has_server -eq 1
                echo bootstrap
            end
            return 0
        case new-session
            echo $argv >> $log_restore
            set -g _two_has_server 1
            return 0
        case list-keys
            echo 'bind-key -T prefix C-r run-shell /tmp/resurrect/scripts/restore.sh'
            return 0
        case run-shell
            echo $argv >> $log_restore
            set -g _two_has_work 1
            return 0
        case kill-session attach-session switch-client
            echo $argv >> $log_restore
            return 0
    end
end
function tmuxinator; echo tmuxinator $argv >> $log_restore; end

_two_function

@test "restore path invokes restore script" (grep -c "run-shell /tmp/resurrect/scripts/restore.sh" $log_restore) -ge 1
@test "restore path attaches restored work session" (grep -c "attach-session -t work" $log_restore) -ge 1
@test "restore path skips tmuxinator fallback" (grep -c "tmuxinator" $log_restore) -eq 0

# ── no restore path, inside tmux → detached tmuxinator start ─
set log (mktemp)
set -gx TMUX /tmp/tmux-work-test
function tmux
    if test "$argv[1]" = has-session; return 1; end
    if test "$argv[1]" = list-keys; echo ""; return; end
    if test "$argv[1]" = list-sessions; echo primary; return 0; end
    echo $argv >> $log
end
function tmuxinator; echo "TMUX=$TMUX" $argv >> $log; end

_two_function

@test "missing work session inside tmux starts detached" (grep -c "TMUX= start work --no-attach" $log) -ge 1
@test "missing work session inside tmux switches client" (grep -c "switch-client -t work" $log) -ge 1

# ── session exists, outside tmux → attach ────────────────
set log2 (mktemp)
set -e TMUX
function tmux
    if test "$argv[1]" = has-session; return 0; end
    echo $argv >> $log2
end

_two_function

@test "existing work session attaches" (grep -c "attach-session -t work" $log2) -ge 1

rm -f $log_restore $log $log2
