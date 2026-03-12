set fn ../../home-manager/programs/fish/functions
source $fn/_fzf_chrome_history.fish

set tmpdir (mktemp -d)
set -x HOME $tmpdir

function commandline; end

@test "no chrome history prints error" (string match -q "*Chrome history not found*" (_fzf_chrome_history 2>&1); echo $status) = 0
@test "no chrome history returns 1" (_fzf_chrome_history >/dev/null 2>/dev/null; echo $status) = 1

rm -rf $tmpdir
