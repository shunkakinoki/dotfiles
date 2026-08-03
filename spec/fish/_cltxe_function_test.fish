set fn (status dirname)/../../home-manager/programs/fish/functions
source $fn/_caam_exec_function.fish
source $fn/_cltxe_function.fish
set -gx CAAM_ROTATION_ENABLED 1

# ── no args: interactive mode ─────────────────────────────
set log1 (mktemp)
function caam; echo $argv >> $log1; end

_cltxe_function

@test "no args uses --worktree --tmux flags" (grep -c -- "--worktree" $log1) -ge 1
@test "no args skips --print flag" (grep -c -- "--print" $log1) -eq 0
@test "no args routes Claude through CAAM" (grep -c '^run claude --precheck -- ' $log1) -ge 1

# ── with args: print mode ─────────────────────────────────
set log2 (mktemp)
function caam; echo $argv >> $log2; end

_cltxe_function hello world

@test "with args uses --print flag" (grep -c -- "--print" $log2) -ge 1
@test "with args uses --tmux flag" (grep -c -- "--tmux" $log2) -ge 1
@test "with args builds prompt" (grep -c "hello world" $log2) -ge 1

set -e CAAM_ROTATION_ENABLED
rm -f $log1 $log2
