set fn (status dirname)/../../home-manager/programs/fish/functions
source $fn/_coxe_function.fish

# ── no args: interactive mode ─────────────────────────────
set log1 (mktemp)
function codex; echo $argv >> $log1; end

_coxe_function

@test "no args calls codex without exec" (grep -c -- " exec " $log1) -eq 0

# ── with args: exec mode ──────────────────────────────────
set log2 (mktemp)
function codex; echo $argv >> $log2; end

_coxe_function hello world

@test "with args uses exec subcommand" (grep -c "^exec " $log2) -ge 1
@test "with args builds prompt" (grep -c "hello world" $log2) -ge 1

# ── resume mode ────────────────────────────────────────────
set log3 (mktemp)
function codex; echo $argv >> $log3; end

_coxe_function --resume session-123

@test "resume uses resume subcommand" (grep -c '^resume session-123$' $log3) -ge 1

rm -f $log1 $log2 $log3
