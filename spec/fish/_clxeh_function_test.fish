set fn ../../home-manager/programs/fish/functions
source $fn/_clxeh_function.fish

@test "empty prompt rejects" (echo "" | _clxeh_function 2>&1) = "No prompt provided, aborting."
@test "empty prompt returns 1" (echo "" | _clxeh_function 2>/dev/null; echo $status) = 1
