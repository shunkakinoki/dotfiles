set fn (status dirname)/../../home-manager/programs/fish/functions
source $fn/_ssxe_function.fish

set log (mktemp)
set mock_bin (mktemp -d)
set -gx SSXE_FUNCTION_LOG $log
set -gx PATH $mock_bin $PATH

for command in fish ssh tailscale
  printf '%s\n' '#!/bin/sh' "printf '$command %s\\n' \"\$*\" >>\"\$SSXE_FUNCTION_LOG\"" >$mock_bin/$command
  chmod +x $mock_bin/$command
end

_ssxe_function echo "hello world"

@test "runs the command locally through Fish" \
  (string match -q -- "fish -lc echo 'hello world'" (cat $log); echo $status) -eq 0
@test "runs the command on Kyber through OpenSSH" \
  (string match -q -- "ssh kyber fish -lc echo 'hello world'" (cat $log); echo $status) -eq 0
@test "runs the command on Matic through Tailscale SSH" \
  (string match -q -- "tailscale ssh shunkakinoki@matic fish -lc echo 'hello world'" (cat $log); echo $status) -eq 0

printf '%s\n' '#!/bin/sh' 'printf "ssh %s\n" "$*" >>"$SSXE_FUNCTION_LOG"' 'exit 1' >$mock_bin/ssh
chmod +x $mock_bin/ssh

@test "returns failure when a target fails" (_ssxe_function true >/dev/null 2>/dev/null; echo $status) -eq 1

@test "requires a command" (_ssxe_function >/dev/null 2>/dev/null; echo $status) -eq 2

rm -rf $mock_bin
rm -f $log
