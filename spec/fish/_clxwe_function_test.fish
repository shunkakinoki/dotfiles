set fn (status dirname)/../../home-manager/programs/fish/functions
source $fn/_clxwe_function.fish

# ── no args: interactive mode ─────────────────────────────
set log1 (mktemp)
function claude; echo $argv >> $log1; end

_clxwe_function

@test "no args uses --worktree flag" (grep -c -- "--worktree" $log1) -ge 1
@test "no args skips --print flag" (grep -c -- "--print" $log1) -eq 0

# ── with args: print mode ─────────────────────────────────
set log2 (mktemp)
function claude; echo $argv >> $log2; end

_clxwe_function hello world

@test "with args uses --print flag" (grep -c -- "--print" $log2) -ge 1
@test "with args uses --worktree flag" (grep -c -- "--worktree" $log2) -ge 1
@test "with args builds prompt" (grep -c "hello world" $log2) -ge 1

rm -f $log1 $log2
