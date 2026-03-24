set fn (status dirname)/../../home-manager/programs/fish/functions
source $fn/_clwxeh_function.fish

@test "empty prompt rejects" (echo "" | _clwxeh_function 2>&1) = "No prompt provided, aborting."
@test "empty prompt returns 1" (echo "" | _clwxeh_function 2>/dev/null; echo $status) = 1

set log1 (mktemp)
function claude; echo $argv >> $log1; end

_clwxeh_function hello world

@test "inline args forwards prompt" (grep -c "hello world" $log1) -ge 1
@test "inline args uses print mode" (grep -c -- "--print" $log1) -ge 1

rm -f $log1
