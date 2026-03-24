set fn (status dirname)/../../home-manager/programs/fish/functions
source $fn/_pixeh_function.tpl.fish

@test "empty prompt rejects" (echo "" | _pixeh_function 2>&1) = "No prompt provided, aborting."
@test "empty prompt returns 1" (echo "" | _pixeh_function 2>/dev/null; echo $status) = 1

set log1 (mktemp)
function pi; echo $argv >> $log1; end

echo "hello world" | _pixeh_function

@test "non-empty prompt builds prompt" (grep -c "hello world" $log1) -ge 1
@test "non-empty prompt uses templated cliproxyapi model" (grep -c "cliproxyapi/__GLM__" $log1) -ge 1
@test "non-empty prompt uses print mode" (grep -c -- "-p" $log1) -ge 1

set log2 (mktemp)
function pi; echo $argv >> $log2; end

_pixeh_function hello world

@test "inline args forwards prompt" (grep -c "hello world" $log2) -ge 1
@test "inline args uses print mode" (grep -c -- "-p" $log2) -ge 1

rm -f $log1 $log2
