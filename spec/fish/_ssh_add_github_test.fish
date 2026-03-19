set fn (status dirname)/../../home-manager/programs/fish/functions
source $fn/_ssh_add_github.fish

set tmpdir (mktemp -d)
set -x HOME $tmpdir

# ── key file missing ───────────────────────────────────────
@test "missing key prints error" (string match -q "*GitHub SSH key not found*" (_ssh_add_github 2>&1); echo $status) = 0
@test "missing key returns 1" (_ssh_add_github >/dev/null 2>/dev/null; echo $status) = 1

# ── key exists but keychain missing ───────────────────────
mkdir -p $tmpdir/.ssh
touch $tmpdir/.ssh/id_ed25519_github
# Filter keychain binary out of PATH so command -v keychain fails
set -l old_PATH $PATH
set -x PATH (for p in $PATH; if not test -x $p/keychain; echo $p; end; end)

@test "no keychain prints error" (string match -q "*keychain not found*" (_ssh_add_github 2>&1); echo $status) = 0

set -x PATH $old_PATH
rm -rf $tmpdir
