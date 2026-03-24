set fn (status dirname)/../../home-manager/programs/fish/functions
source $fn/_pixelh_function.fish

@test "empty prompt rejects" (echo "" | _pixelh_function 2>&1) = "No prompt provided, aborting."
@test "empty prompt returns 1" (echo "" | _pixelh_function 2>/dev/null; echo $status) = 1

set log1 (mktemp)
function pi; echo $argv >> $log1; end

echo "hello world" | _pixelh_function

@test "non-empty prompt builds prompt" (grep -c "hello world" $log1) -ge 1
@test "non-empty prompt uses local Qwen model" (grep -c "lmstudio/qwen/qwen3.5-9b" $log1) -ge 1
@test "non-empty prompt uses print mode" (grep -c -- "-p" $log1) -ge 1

set log2 (mktemp)
function pi; echo $argv >> $log2; end

_pixelh_function hello world

@test "inline args forwards prompt" (grep -c "hello world" $log2) -ge 1
@test "inline args uses print mode" (grep -c -- "-p" $log2) -ge 1

rm -f $log1 $log2
