set fn (status dirname)/../../home-manager/programs/fish/functions
source $fn/_coxel_function.fish

# ── no args: interactive mode ─────────────────────────────
set log1 (mktemp)
function codex; echo $argv >> $log1; end

_coxel_function

@test "no args uses substituted Qwen model" (grep -c "qwen/qwen3.5-9b" $log1) -ge 1
@test "no args enables oss mode" (grep -c -- "--oss" $log1) -ge 1
@test "no args uses lmstudio local provider" (grep -c -- "local-provider lmstudio" $log1) -ge 1
@test "no args lowers reasoning effort" (grep -c "model_reasoning_effort=minimal" $log1) -ge 1

# ── with args: exec mode ──────────────────────────────────
set log2 (mktemp)
function codex; echo $argv >> $log2; end

_coxel_function hello world

@test "with args uses exec subcommand" (grep -c "^exec " $log2) -ge 1
@test "with args builds prompt" (grep -c "hello world" $log2) -ge 1
@test "with args uses substituted Qwen model" (grep -c "qwen/qwen3.5-9b" $log2) -ge 1
@test "with args enables oss mode" (grep -c -- "--oss" $log2) -ge 1
@test "with args uses lmstudio local provider" (grep -c -- "local-provider lmstudio" $log2) -ge 1
@test "with args lowers reasoning effort" (grep -c "model_reasoning_effort=minimal" $log2) -ge 1

rm -f $log1 $log2
