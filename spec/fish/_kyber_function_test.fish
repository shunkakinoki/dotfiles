set fn (status dirname)/../../home-manager/programs/fish/functions
source $fn/_kyber_function.fish

set log (mktemp)
function ssh; echo "ssh $argv" >> $log; end
function tailscale; echo "tailscale $argv" >> $log; return 1; end

_kyber_function

@test "calls OpenSSH through the kyber host alias" (grep -c "^ssh kyber\$" $log) -eq 1
@test "does not call the Tailscale SSH wrapper" (grep -c "^tailscale " $log) -eq 0

rm -f $log
