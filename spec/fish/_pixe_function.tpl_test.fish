set fn (status dirname)/../../home-manager/programs/fish/functions
source $fn/_pixe_function.tpl.fish

# ── no args: interactive mode ─────────────────────────────
set log1 (mktemp)
function pi-agent; echo $argv >> $log1; end

_pixe_function

@test "no args calls pi-agent with templated preset" (grep -c "openrouter-preset/@preset/__GLM_NONDOT__" $log1) -ge 1

# ── with args: builds prompt ──────────────────────────────
set log2 (mktemp)
function pi-agent; echo $argv >> $log2; end

_pixe_function hello world

@test "with args builds prompt" (grep -c "hello world" $log2) -ge 1
@test "with args uses templated preset" (grep -c "openrouter-preset/@preset/__GLM_NONDOT__" $log2) -ge 1

rm -f $log1 $log2
