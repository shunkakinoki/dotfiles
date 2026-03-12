set fn ../../home-manager/programs/fish/functions
source $fn/_coxelh_function.fish

@test "empty prompt rejects" (echo "" | _coxelh_function 2>&1) = "No prompt provided, aborting."
@test "empty prompt returns 1" (echo "" | _coxelh_function 2>/dev/null; echo $status) = 1
