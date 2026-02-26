set fn (status dirname)/../../home-manager/programs/fish/functions
source $fn/_tsh_function.fish

set tmpdir (mktemp -d)
set -x HOME $tmpdir

@test "reports missing pane dir" (string match -q "*No pane content store found*" (_tsh_function 2>&1); echo $status) = 0

rm -rf $tmpdir
