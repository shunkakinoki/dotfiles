set fn (status dirname)/../../home-manager/programs/fish/functions
source $fn/_llm_update_function.fish

set tmpdir (mktemp -d)

set -x HOME $tmpdir
_llm_update_function >/dev/null 2>&1
@test "returns 1 when script missing" $status = 1

rm -rf $tmpdir
