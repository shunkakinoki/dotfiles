set fn (status dirname)/../../home-manager/programs/fish/functions
source $fn/_kyber_function.fish

set log (mktemp)
function tailscale; echo $argv >> $log; end

_kyber_function

@test "calls tailscale ssh to kyber" (grep -c "ssh ubuntu@kyber" $log) -ge 1

rm -f $log
