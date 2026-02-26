set fn (status dirname)/../../home-manager/programs/fish/functions
source $fn/_pixe_function.fish

# ── no args: interactive mode ─────────────────────────────
set log1 (mktemp)
function pi-agent; echo $argv >> $log1; end

_pixe_function

@test "no args calls pi-agent with model" (grep -c "openrouter-preset" $log1) -ge 1

# ── with args: builds prompt ──────────────────────────────
set log2 (mktemp)
function pi-agent; echo $argv >> $log2; end

_pixe_function hello world

@test "with args builds prompt" (grep -c "hello world" $log2) -ge 1

rm -f $log1 $log2
