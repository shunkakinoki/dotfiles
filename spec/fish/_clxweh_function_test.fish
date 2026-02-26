set fn (status dirname)/../../home-manager/programs/fish/functions
source $fn/_clxweh_function.fish

@test "empty prompt rejects" (echo "" | _clxweh_function 2>&1) = "No prompt provided, aborting."
@test "empty prompt returns 1" (echo "" | _clxweh_function 2>/dev/null; echo $status) = 1
