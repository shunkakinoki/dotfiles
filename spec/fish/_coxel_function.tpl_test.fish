set fn (status dirname)/../../home-manager/programs/fish/functions
source $fn/_coxel_function.tpl.fish

# ── no args: interactive mode ─────────────────────────────
set log1 (mktemp)
function codex; echo $argv >> $log1; end

_coxel_function

@test "no args uses QWEN_LOCAL placeholder" (grep -c "__QWEN_LOCAL__" $log1) -ge 1
@test "no args forces lmstudio provider" (grep -c "model_provider=lmstudio" $log1) -ge 1

# ── with args: exec mode ──────────────────────────────────
set log2 (mktemp)
function codex; echo $argv >> $log2; end

_coxel_function hello world

@test "with args uses exec subcommand" (grep -c "^exec " $log2) -ge 1
@test "with args builds prompt" (grep -c "hello world" $log2) -ge 1
@test "with args uses QWEN_LOCAL placeholder" (grep -c "__QWEN_LOCAL__" $log2) -ge 1
@test "with args forces lmstudio provider" (grep -c "model_provider=lmstudio" $log2) -ge 1

rm -f $log1 $log2
