set fn (status dirname)/../../home-manager/programs/fish/functions
source $fn/_maticd_function.fish

set log (mktemp)
function tailscale; echo 100.1.2.3; end
function ssh; echo $argv >> $log; end

_maticd_function

@test "calls ssh to matic IP" (grep -c "shunkakinoki@100.1.2.3" $log) -ge 1
@test "attaches to desktop session" (grep -c "desktop" $log) -ge 1

rm -f $log
