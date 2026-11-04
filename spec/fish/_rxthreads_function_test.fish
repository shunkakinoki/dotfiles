set fn (status dirname)/../../home-manager/programs/fish/functions
set -l test_home (mktemp -d)
set -l error_file (mktemp)
env HOME=$test_home fish --no-config -c 'source "$argv[1]"; _rxthreads_function' -- "$fn/_rxthreads_function.fish" 2>$error_file
set -l result $status
@test "missing worker state fails" $result -eq 1
@test "missing worker state is explained" (grep -c 'no worker port' $error_file) -eq 1
rm -rf $test_home
rm -f $error_file
