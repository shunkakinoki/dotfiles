set fn (status dirname)/../../home-manager/programs/fish/functions
source $fn/_tsh_function.fish

set tmpdir (mktemp -d)
set -x HOME $tmpdir

@test "reports missing pane dir" (string match -q "*No pane content store found*" (_tsh_function 2>&1); echo $status) = 0

# ── bat-always: active session should not be switched to ──
mkdir -p $tmpdir/.local/share/tmux/panes
set pane_file $tmpdir/.local/share/tmux/panes/mysess--0--0.txt
echo "pane content here" > $pane_file

set -g switched ""
function tmux
    if string match -q "has-session*" "$argv"
        return 0  # session "exists"
    end
    set -g switched "yes"
end
function rg; echo $pane_file; end
function fzf; echo $pane_file; end
function bat; cat $argv[-1] 2>/dev/null; end

@test "does not switch to active session" $switched = ""
@test "bats the selected file" (string match -q "*pane content here*" (_tsh_function 2>&1); echo $status) = 0

rm -rf $tmpdir
