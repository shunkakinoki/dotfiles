set fn ../../home-manager/programs/fish/functions
source $fn/_zdo_function.fish

set log (mktemp)
function zellij; echo $argv >> $log; end

_zdo_function

@test "attaches to desktop zellij session" (grep -c "attach desktop" $log) -ge 1

rm -f $log
