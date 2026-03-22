set fn (status dirname)/../../home-manager/programs/fish/functions
source $fn/_ompxe_function.fish

# ── no args: interactive mode ─────────────────────────────
set log1 (mktemp)
function omp; echo "argc="(count $argv) >> $log1; for arg in $argv; echo "arg=$arg" >> $log1; end; end

_ompxe_function

@test "no args calls omp without prompt args" (grep -Fx -c 'argc=0' $log1) -ge 1

# ── with args: builds prompt ──────────────────────────────
set log2 (mktemp)
function omp; echo "argc="(count $argv) >> $log2; for arg in $argv; echo "arg=$arg" >> $log2; end; end

_ompxe_function hello world

@test "with args passes a single prompt argument" (grep -Fx -c 'argc=1' $log2) -ge 1
@test "with args preserves spaces in the prompt" (grep -Fx -c 'arg=hello world' $log2) -ge 1

rm -f $log1 $log2
