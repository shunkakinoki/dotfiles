set fn (status dirname)/../../home-manager/programs/fish/functions
source $fn/_kyberh_function.fish

set call_log (mktemp)

function herdr; echo $argv >> $call_log; end

_kyberh_function

@test "passes --remote kyber" (grep -c -- "--remote kyber" $call_log) -ge 1

rm -f $call_log
