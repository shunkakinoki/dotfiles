set fn (status dirname)/../../home-manager/programs/fish/functions
source $fn/_vpn_function.fish

function sudo; echo "sudo $argv"; end
function tailscale; echo "tailscale $argv"; end

@test "function is defined after sourcing" (functions -q _vpn_function; echo $status) = 0
@test "vpn status calls tailscale status" (_vpn_function status) = "tailscale status"
