set fn (status dirname)/../../home-manager/programs/fish/functions
source $fn/_coxelh_function.tpl.fish

@test "empty prompt rejects" (echo "" | _coxelh_function 2>&1) = "No prompt provided, aborting."
@test "empty prompt returns 1" (echo "" | _coxelh_function 2>/dev/null; echo $status) = 1

set log1 (mktemp)
function codex; echo $argv >> $log1; end

echo "hello world" | _coxelh_function

@test "non-empty prompt uses exec subcommand" (grep -c "^exec " $log1) -ge 1
@test "non-empty prompt uses QWEN_LOCAL placeholder" (grep -c "__QWEN_LOCAL__" $log1) -ge 1
@test "non-empty prompt forces lmstudio provider" (grep -c "model_provider=lmstudio" $log1) -ge 1
@test "non-empty prompt forwards prompt" (grep -c "hello world" $log1) -ge 1

rm -f $log1
