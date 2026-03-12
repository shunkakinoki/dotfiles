set fn ../../home-manager/programs/fish/functions
source $fn/_clwxeh_function.fish

@test "empty prompt rejects" (echo "" | _clwxeh_function 2>&1) = "No prompt provided, aborting."
@test "empty prompt returns 1" (echo "" | _clwxeh_function 2>/dev/null; echo $status) = 1
