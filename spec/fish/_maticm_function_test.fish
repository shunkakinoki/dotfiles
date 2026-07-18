set fn (status dirname)/../../home-manager/programs/fish/functions
source $fn/_maticm_function.fish

set log (mktemp)
function tailscale; echo 100.1.2.3; end
function ssh; echo $argv >> $log; end

_maticm_function

@test "calls ssh to matic IP" (grep -c "shunkakinoki@100.1.2.3" $log) -ge 1
@test "attaches to mobile session" (grep -c "mobile" $log) -ge 1

rm -f $log
