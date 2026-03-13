set fn (status dirname)/../../home-manager/programs/fish/functions
source $fn/_pixeh_function.fish

@test "empty prompt rejects" (echo "" | _pixeh_function 2>&1) = "No prompt provided, aborting."
@test "empty prompt returns 1" (echo "" | _pixeh_function 2>/dev/null; echo $status) = 1

set log1 (mktemp)
function pi; echo $argv >> $log1; end

echo "hello world" | _pixeh_function

@test "non-empty prompt builds prompt" (grep -c "hello world" $log1) -ge 1
@test "non-empty prompt uses cliproxyapi model" (grep -c "cliproxyapi/glm-4.7" $log1) -ge 1
@test "non-empty prompt uses print mode" (grep -c -- "-p" $log1) -ge 1

rm -f $log1
