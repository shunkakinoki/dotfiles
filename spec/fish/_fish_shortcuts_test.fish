set fn (status dirname)/../../home-manager/programs/fish/functions
source $fn/_fish_shortcuts.fish

@test "function is defined after sourcing" (functions -q _fish_shortcuts; echo $status) = 0
@test "fish_shortcuts alias is defined" (functions -q fish_shortcuts; echo $status) = 0
