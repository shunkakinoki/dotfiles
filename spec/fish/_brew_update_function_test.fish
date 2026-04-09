set fn (status dirname)/../../home-manager/programs/fish/functions
source $fn/_brew_update_function.fish

# ── normal update flow ─────────────────────────────────────
set log (mktemp)
function brew
    echo $argv >> $log
end

_brew_update

@test "updates homebrew" (grep -c "update" $log) -ge 1
@test "upgrades homebrew" (grep -c "upgrade" $log) -ge 1
@test "cleans up homebrew" (grep -c "cleanup" $log) -ge 1

rm -f $log