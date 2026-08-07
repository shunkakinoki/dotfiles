set fn (status dirname)/../../home-manager/programs/fish/functions
source $fn/_ssxe_function.fish

set log (mktemp)

function sh
  echo "sh $argv" >> $log
end

function ssh
  echo "ssh $argv" >> $log
  cat >> $log
end

function tailscale
  echo "tailscale $argv" >> $log
  cat >> $log
end

_ssxe_function echo hello

@test "runs the command locally" (grep -c '^sh -c echo hello$' $log) -eq 1
@test "sends the command to Kyber through OpenSSH" (grep -c '^ssh kyber sh -s$' $log) -eq 1
@test "sends the command to Matic through Tailscale SSH" (grep -c '^tailscale ssh shunkakinoki@matic sh -s$' $log) -eq 1
@test "streams the command to both remote hosts" (grep -c '^echo hello$' $log) -eq 2

rm -f $log
