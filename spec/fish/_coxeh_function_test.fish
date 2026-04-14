set fn (status dirname)/../../home-manager/programs/fish/functions
source $fn/_coxeh_function.fish

@test "empty prompt rejects" (echo "" | _coxeh_function 2>&1) = "No prompt provided, aborting."
@test "empty prompt returns 1" (echo "" | _coxeh_function 2>/dev/null; echo $status) = 1

set log1 (mktemp)
function codex; echo $argv >> $log1; end

_coxeh_function hello world

@test "inline args forwards prompt" (grep -c "hello world" $log1) -ge 1
@test "inline args includes bypass flag" (grep -c -- "--dangerously-bypass-approvals-and-sandbox" $log1) -ge 1

rm -f $log1
