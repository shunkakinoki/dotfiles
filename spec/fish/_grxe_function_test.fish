set fn (status dirname)/../../home-manager/programs/fish/functions
source $fn/_grxe_function.fish

# ── no args: interactive mode ─────────────────────────────
set log1 (mktemp)
function grok; echo $argv >> $log1; end

_grxe_function

@test "no args skips --single flag" (grep -c -- "--single" $log1) -eq 0
@test "no args uses always-approve" (grep -c "always-approve" $log1) -ge 1

# ── with args: single (headless) mode ─────────────────────
set log2 (mktemp)
function grok; echo $argv >> $log2; end

_grxe_function hello world

@test "with args uses --single flag" (grep -c -- "--single" $log2) -ge 1
@test "with args builds prompt" (grep -c "hello world" $log2) -ge 1

rm -f $log1 $log2
