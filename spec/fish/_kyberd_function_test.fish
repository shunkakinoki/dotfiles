set fn ../../home-manager/programs/fish/functions
source $fn/_kyberd_function.fish

set log (mktemp)
function tailscale; echo 100.1.2.3; end
function ssh; echo $argv >> $log; end

_kyberd_function

@test "calls ssh to kyber IP" (grep -c "ubuntu@100.1.2.3" $log) -ge 1
@test "attaches to desktop session" (grep -c "desktop" $log) -ge 1

rm -f $log
