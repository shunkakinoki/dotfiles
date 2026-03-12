set fn ../../home-manager/programs/fish/functions
source $fn/_tsh_function.fish

set tmpdir (mktemp -d)
set -x HOME $tmpdir

@test "reports missing pane dir" (string match -q "*No pane content store found*" (_tsh_function 2>&1); echo $status) = 0

# ── archive file → bat, no session switch ──
mkdir -p $tmpdir/.local/share/tmux/panes
mkdir -p $tmpdir/.local/share/tmux/archive
set archive_file $tmpdir/.local/share/tmux/archive/mysess--0--0--20260226-103000.txt
echo "archived content" > $archive_file

set -g switched ""
function tmux; set -g switched "yes"; end
function rg; echo $archive_file; end
function fzf; echo $archive_file; end
function bat; cat $argv[-1] 2>/dev/null; end

@test "archive: does not switch session" $switched = ""
@test "archive: bats the file" (string match -q "*archived content*" (_tsh_function 2>&1); echo $status) = 0

# ── live pane file → switch (tmux called) ──
set pane_file $tmpdir/.local/share/tmux/panes/mysess--0--0.txt
echo "live content" > $pane_file

set -g switched ""
function tmux; set -g switched "yes"; end
function rg; echo $pane_file; end
function fzf; echo $pane_file; end

_tsh_function 2>/dev/null
@test "live pane: switches session" $switched = "yes"

rm -rf $tmpdir
