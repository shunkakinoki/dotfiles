set fn (status dirname)/../../home-manager/programs/fish/functions
source $fn/_sync_local_binaries_function.fish

set tmpdir (mktemp -d)

# ── script not found returns 1 ───────────────────────────
set -x HOME $tmpdir
_sync_local_binaries_function >/dev/null 2>&1
@test "returns 1 when script missing" $status = 1

rm -rf $tmpdir
