set fn (status dirname)/../../home-manager/programs/fish/functions
source $fn/_coxeh_function.tpl.fish

@test "empty prompt rejects" (echo "" | _coxeh_function 2>&1) = "No prompt provided, aborting."
@test "empty prompt returns 1" (echo "" | _coxeh_function 2>/dev/null; echo $status) = 1
