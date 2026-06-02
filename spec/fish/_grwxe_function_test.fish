set fn (status dirname)/../../home-manager/programs/fish/functions
source $fn/_grwxe_function.fish

# ── no args: interactive mode ─────────────────────────────
set log1 (mktemp)
function grok; echo $argv >> $log1; end

_grwxe_function

@test "no args uses --worktree flag" (grep -c -- "--worktree" $log1) -ge 1
@test "no args skips --single flag" (grep -c -- "--single" $log1) -eq 0

# ── with args: single (headless) mode ─────────────────────
set log2 (mktemp)
function grok; echo $argv >> $log2; end

_grwxe_function hello world

@test "with args uses --single flag" (grep -c -- "--single" $log2) -ge 1
@test "with args uses --worktree flag" (grep -c -- "--worktree" $log2) -ge 1
@test "with args builds prompt" (grep -c "hello world" $log2) -ge 1

rm -f $log1 $log2
