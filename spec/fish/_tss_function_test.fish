set fn (status dirname)/../../home-manager/programs/fish/functions
source $fn/_tss_function.fish

set tmpdir (mktemp -d)
set -x HOME $tmpdir

# ── --log branch: no log file ─────────────────────────────
@test "no log file returns message" (string match -q "*No session history found*" (_tss_function --log 2>&1); echo $status) = 0

# ── no selection exits cleanly ───────────────────────────
function tmux; end
function fzf; end
function tmuxinator; end

@test "no fzf selection exits cleanly" (_tss_function; echo done) = done

# ── missing work selection delegates to _two_function ─────
set log_work (mktemp)
function fzf; echo work; end
function tmux
    if test "$argv[1]" = has-session; return 1; end
end
function _two_function; echo delegated >> $log_work; end

_tss_function

@test "missing work selection delegates to _two_function" (grep -c delegated $log_work) -ge 1

# ── missing primary selection delegates to _tpo_function ──
set log_primary (mktemp)
function fzf; echo primary; end
function tmux
    if test "$argv[1]" = has-session
        return 1
    end
end
function _tpo_function; echo delegated >> $log_primary; end

_tss_function

@test "missing primary selection delegates to _tpo_function" (grep -c delegated $log_primary) -ge 1

rm -rf $tmpdir
rm -f $log_work $log_primary
