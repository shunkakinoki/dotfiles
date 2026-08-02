set fn (status dirname)/../../home-manager/programs/fish/functions
source $fn/_matich_function.fish

set call_log (mktemp)

function herdr; echo $argv >> $call_log; end

_matich_function

@test "passes --remote matic" (grep -c -- "--remote matic" $call_log) -ge 1

rm -f $call_log
