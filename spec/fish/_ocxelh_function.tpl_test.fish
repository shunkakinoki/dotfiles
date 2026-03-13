set fn (status dirname)/../../home-manager/programs/fish/functions
source $fn/_ocxelh_function.tpl.fish

@test "empty prompt rejects" (echo "" | _ocxelh_function 2>&1) = "No prompt provided, aborting."
@test "empty prompt returns 1" (echo "" | _ocxelh_function 2>/dev/null; echo $status) = 1

set log1 (mktemp)
function opencode; echo $argv >> $log1; end

echo "hello world" | _ocxelh_function

@test "non-empty prompt uses run subcommand" (grep -c "^run " $log1) -ge 1
@test "non-empty prompt builds prompt" (grep -c "hello world" $log1) -ge 1
@test "non-empty prompt uses templated local Qwen model" (grep -c "lmstudio/__QWEN_LOCAL__" $log1) -ge 1

rm -f $log1
