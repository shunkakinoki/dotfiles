set function_file (status dirname)/../../named-hosts/kyber/t3.fish
set mock_bin (mktemp -d)
set call_log (mktemp)

printf '%s\n' '#!/usr/bin/env bash' 'printf "%s\n" "$*" >>"$T3_CALL_LOG"' >$mock_bin/t3
chmod +x $mock_bin/t3
set -gx T3_CALL_LOG $call_log
set -gx PATH $mock_bin $PATH

source $function_file

t3 pair --tailscale
@test "defaults Tailscale pairing to Kyber port 8443" (tail -n 1 $call_log) = "pair --tailscale --tailscale-serve-port 8443"

t3 pair --tailscale --tailscale-serve-port 10443
@test "preserves a separate explicit port argument" (tail -n 1 $call_log) = "pair --tailscale --tailscale-serve-port 10443"

t3 pair --tailscale --tailscale-serve-port=9443
@test "preserves an inline explicit port argument" (tail -n 1 $call_log) = "pair --tailscale --tailscale-serve-port=9443"

t3 pair
@test "leaves direct pairing unchanged" (tail -n 1 $call_log) = "pair"

t3 service status
@test "leaves unrelated T3 commands unchanged" (tail -n 1 $call_log) = "service status"

rm -rf $mock_bin
rm -f $call_log
