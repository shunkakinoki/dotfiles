set fn ../../home-manager/programs/fish/functions
source $fn/_dev_function.fish

set tmpdir (mktemp -d)
mkdir -p $tmpdir/child/grandchild

# Mock nix so devshell doesn't actually launch
function nix; end

# ── cwd has flake.nix ─────────────────────────────────────
touch $tmpdir/child/flake.nix
@test "uses cwd" (cd $tmpdir/child; _dev_function) = "Entering devshell in $tmpdir/child"

# ── grandchild → walks up to parent ──────────────────────
@test "walks up to parent" (cd $tmpdir/child/grandchild; _dev_function) = "Entering devshell in $tmpdir/child"

# ── no flake.nix → falls back to ~/dotfiles ──────────────
rm $tmpdir/child/flake.nix
set -x HOME $tmpdir
mkdir -p $tmpdir/dotfiles
@test "falls back to dotfiles" (cd $tmpdir/child/grandchild; _dev_function) = "Entering devshell in $tmpdir/dotfiles"

rm -rf $tmpdir
