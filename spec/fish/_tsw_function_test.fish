set fn (status dirname)/../../home-manager/programs/fish/functions
source $fn/_tsw_function.fish

set tmpdir (mktemp -d)
set -x HOME $tmpdir

# ── --log branch: no log file ─────────────────────────────
@test "no log file returns message" (string match -q "*No session history found*" (_tsw_function --log 2>&1); echo $status) = 0

# ── no selection exits cleanly ───────────────────────────
function tmux; end
function fzf; end

@test "no fzf selection exits cleanly" (_tsw_function; echo done) = done

rm -rf $tmpdir
