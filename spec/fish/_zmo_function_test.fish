set fn ../../home-manager/programs/fish/functions
source $fn/_zmo_function.fish

set log (mktemp)
function zellij; echo $argv >> $log; end

_zmo_function

@test "attaches to mobile zellij session" (grep -c "attach mobile" $log) -ge 1

rm -f $log
