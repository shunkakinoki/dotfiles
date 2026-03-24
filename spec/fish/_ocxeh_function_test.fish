set fn (status dirname)/../../home-manager/programs/fish/functions
source $fn/_ocxeh_function.fish

@test "empty prompt rejects" (echo "" | _ocxeh_function 2>&1) = "No prompt provided, aborting."
@test "empty prompt returns 1" (echo "" | _ocxeh_function 2>/dev/null; echo $status) = 1

set log1 (mktemp)
function opencode; echo $argv >> $log1; end

_ocxeh_function hello world

@test "inline args forwards prompt" (grep -c "hello world" $log1) -ge 1
@test "inline args uses run subcommand" (grep -c "^run " $log1) -ge 1

rm -f $log1
