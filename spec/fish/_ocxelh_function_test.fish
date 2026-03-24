set fn (status dirname)/../../home-manager/programs/fish/functions
source $fn/_ocxelh_function.fish

@test "empty prompt rejects" (echo "" | _ocxelh_function 2>&1) = "No prompt provided, aborting."
@test "empty prompt returns 1" (echo "" | _ocxelh_function 2>/dev/null; echo $status) = 1

set log1 (mktemp)
function opencode; echo $argv >> $log1; end

echo "hello world" | _ocxelh_function

@test "non-empty prompt uses run subcommand" (grep -c "^run " $log1) -ge 1
@test "non-empty prompt builds prompt" (grep -c "hello world" $log1) -ge 1
@test "non-empty prompt uses local Qwen model" (grep -c "lmstudio/qwen/qwen3.5-9b" $log1) -ge 1

set log2 (mktemp)
function opencode; echo $argv >> $log2; end

_ocxelh_function hello world

@test "inline args forwards prompt" (grep -c "hello world" $log2) -ge 1
@test "inline args uses run subcommand" (grep -c "^run " $log2) -ge 1

rm -f $log1 $log2
