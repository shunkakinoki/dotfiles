set fn (status dirname)/../../home-manager/programs/fish/functions
source $fn/_pixel_function.tpl.fish

# ── no args: interactive mode ─────────────────────────────
set log1 (mktemp)
function pi; echo $argv >> $log1; end

_pixel_function

@test "no args calls pi with templated local Qwen model" (grep -c "lmstudio/__QWEN_LOCAL__" $log1) -ge 1

# ── with args: builds prompt ──────────────────────────────
set log2 (mktemp)
function pi; echo $argv >> $log2; end

_pixel_function hello world

@test "with args builds prompt" (grep -c "hello world" $log2) -ge 1
@test "with args uses templated local Qwen model" (grep -c "lmstudio/__QWEN_LOCAL__" $log2) -ge 1

rm -f $log1 $log2
