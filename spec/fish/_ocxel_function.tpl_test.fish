set fn (status dirname)/../../home-manager/programs/fish/functions
source $fn/_ocxel_function.tpl.fish

# ── no args: interactive mode ─────────────────────────────
set log1 (mktemp)
function opencode; echo $argv >> $log1; end

_ocxel_function

@test "no args calls opencode with templated local Qwen model" (grep -c "lmstudio/__QWEN_LOCAL__" $log1) -ge 1
@test "no args skips run subcommand" (grep -c "^run " $log1) -eq 0

# ── with args: run mode ──────────────────────────────────
set log2 (mktemp)
function opencode; echo $argv >> $log2; end

_ocxel_function hello world

@test "with args uses run subcommand" (grep -c "^run " $log2) -ge 1
@test "with args builds prompt" (grep -c "hello world" $log2) -ge 1
@test "with args uses templated local Qwen model" (grep -c "lmstudio/__QWEN_LOCAL__" $log2) -ge 1

rm -f $log1 $log2
