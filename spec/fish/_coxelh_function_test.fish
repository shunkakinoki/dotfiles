set fn (status dirname)/../../home-manager/programs/fish/functions
source $fn/_coxelh_function.fish

@test "empty prompt rejects" (echo "" | _coxelh_function 2>&1) = "No prompt provided, aborting."
@test "empty prompt returns 1" (echo "" | _coxelh_function 2>/dev/null; echo $status) = 1

set log1 (mktemp)
function codex; echo $argv >> $log1; end

echo "hello world" | _coxelh_function

@test "non-empty prompt uses exec subcommand" (grep -c -- " exec " $log1) -ge 1
@test "non-empty prompt uses substituted Qwen model" (grep -c "qwen3.5-0.8b-optiq" $log1) -ge 1
@test "non-empty prompt enables oss mode" (grep -c -- "--oss" $log1) -ge 1
@test "non-empty prompt uses lmstudio local provider" (grep -c -- "local-provider lmstudio" $log1) -ge 1
@test "non-empty prompt lowers reasoning effort" (grep -c "model_reasoning_effort=minimal" $log1) -ge 1
@test "non-empty prompt forwards prompt" (grep -c "hello world" $log1) -ge 1
@test "non-empty prompt includes bypass flag" (grep -c -- "--dangerously-bypass-approvals-and-sandbox" $log1) -ge 1

set log2 (mktemp)
function codex; echo $argv >> $log2; end

_coxelh_function hello world

@test "inline args forwards prompt" (grep -c "hello world" $log2) -ge 1
@test "inline args uses exec subcommand" (grep -c -- " exec " $log2) -ge 1
@test "inline args includes bypass flag" (grep -c -- "--dangerously-bypass-approvals-and-sandbox" $log2) -ge 1

rm -f $log1 $log2
