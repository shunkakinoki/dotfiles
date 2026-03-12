set fn ../../home-manager/programs/fish/functions
source $fn/_cltxeh_function.fish

@test "empty prompt rejects" (echo "" | _cltxeh_function 2>&1) = "No prompt provided, aborting."
@test "empty prompt returns 1" (echo "" | _cltxeh_function 2>/dev/null; echo $status) = 1
