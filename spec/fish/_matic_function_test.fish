set fn (status dirname)/../../home-manager/programs/fish/functions
source $fn/_matic_function.fish

set log (mktemp)
function tailscale; echo $argv >> $log; end

_matic_function

@test "calls tailscale ssh to matic" (grep -c "ssh shunkakinoki@matic" $log) -ge 1

rm -f $log
