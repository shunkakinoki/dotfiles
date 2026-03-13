set fn (status dirname)/../../home-manager/programs/fish/functions
source $fn/_pixeh_function.tpl.fish

@test "empty prompt rejects" (echo "" | _pixeh_function 2>&1) = "No prompt provided, aborting."
@test "empty prompt returns 1" (echo "" | _pixeh_function 2>/dev/null; echo $status) = 1
