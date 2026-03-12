set fn (status dirname)/../../home-manager/programs/fish/functions
source $fn/fish_user_key_bindings.fish

function bind; end
function commandline; end

@test "function is defined after sourcing" (functions -q fish_user_key_bindings; echo $status) = 0
@test "runs without error" (fish_user_key_bindings; echo done) = done
