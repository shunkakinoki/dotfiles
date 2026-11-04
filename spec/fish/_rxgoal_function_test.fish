set fn (status dirname)/../../home-manager/programs/fish/functions
source $fn/_rxgoal_function.fish
set original_home $HOME
set -gx HOME (mktemp -d)
set -l error_file (mktemp)
_rxgoal_function 2>$error_file
set -l result $status
@test "missing worker state fails" $result -eq 1
@test "missing worker state is explained" (grep -c 'no worker port' $error_file) -eq 1
rm -rf $HOME
rm -f $error_file
set -gx HOME $original_home
