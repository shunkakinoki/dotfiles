set fn (status dirname)/../../home-manager/programs/fish/functions
source $fn/_zpo_function.fish

set log (mktemp)
function zellij; echo $argv >> $log; end

_zpo_function

@test "attaches to primary zellij session" (grep -c "attach primary" $log) -ge 1

rm -f $log
