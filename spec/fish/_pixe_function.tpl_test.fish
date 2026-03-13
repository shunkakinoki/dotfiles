set fn (status dirname)/../../home-manager/programs/fish/functions
source $fn/_pixe_function.tpl.fish

# ── no args: interactive mode ─────────────────────────────
set log1 (mktemp)
function pi; echo $argv >> $log1; end

_pixe_function

@test "no args calls pi with templated cliproxyapi model" (grep -c "cliproxyapi/__GLM__" $log1) -ge 1

# ── with args: builds prompt ──────────────────────────────
set log2 (mktemp)
function pi; echo $argv >> $log2; end

_pixe_function hello world

@test "with args builds prompt" (grep -c "hello world" $log2) -ge 1
@test "with args uses templated cliproxyapi model" (grep -c "cliproxyapi/__GLM__" $log2) -ge 1

rm -f $log1 $log2
