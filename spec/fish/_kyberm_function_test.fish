set fn ../../home-manager/programs/fish/functions
source $fn/_kyberm_function.fish

set log (mktemp)
function tailscale; echo 100.1.2.3; end
function ssh; echo $argv >> $log; end

_kyberm_function

@test "calls ssh to kyber IP" (grep -c "ubuntu@100.1.2.3" $log) -ge 1
@test "attaches to mobile session" (grep -c "mobile" $log) -ge 1

rm -f $log
