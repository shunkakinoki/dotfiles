set fn (status dirname)/../../home-manager/programs/fish/functions
source $fn/_caxe_function.fish

# ── no args: interactive mode ─────────────────────────────
set log1 (mktemp)
function cursor-agent; echo $argv >> $log1; end

_caxe_function

@test "no args skips --print flag" (grep -c -- "--print" $log1) -eq 0
@test "no args uses --force" (grep -c -- "--force" $log1) -ge 1

# ── with args: print mode ─────────────────────────────────
set log2 (mktemp)
function cursor-agent; echo $argv >> $log2; end

_caxe_function hello world

@test "with args uses --print flag" (grep -c -- "--print" $log2) -ge 1
@test "with args builds prompt" (grep -c "hello world" $log2) -ge 1

rm -f $log1 $log2
