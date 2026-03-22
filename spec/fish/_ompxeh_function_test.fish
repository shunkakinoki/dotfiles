set fn (status dirname)/../../home-manager/programs/fish/functions
source $fn/_ompxeh_function.fish

@test "empty prompt rejects" (echo "" | _ompxeh_function 2>&1) = "No prompt provided, aborting."
@test "empty prompt returns 1" (echo "" | _ompxeh_function 2>/dev/null; echo $status) = 1

set log1 (mktemp)
function omp; echo "argc="(count $argv) >> $log1; for arg in $argv; echo "arg=$arg" >> $log1; end; end

echo "hello world" | _ompxeh_function

@test "non-empty prompt passes two arguments" (grep -Fx -c 'argc=2' $log1) -ge 1
@test "non-empty prompt uses print mode" (grep -Fx -c 'arg=-p' $log1) -ge 1
@test "non-empty prompt preserves spaces in the prompt" (grep -Fx -c 'arg=hello world' $log1) -ge 1

rm -f $log1
