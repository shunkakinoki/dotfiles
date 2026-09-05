set fn (status dirname)/../../home-manager/programs/fish/functions
source $fn/_git_index_lock_wait.fish

set test_repo (mktemp -d)
git -C $test_repo init --quiet

pushd $test_repo >/dev/null
_git_index_lock_wait 0
set unlocked_status $status

touch .git/index.lock
_git_index_lock_wait 0 2>/dev/null
set stale_status $status
set stale_lock_exists (test -e .git/index.lock; echo $status)
popd >/dev/null

@test "returns success when no index lock exists" $unlocked_status -eq 0
@test "removes an unheld stale index lock" $stale_status -eq 0
@test "leaves no stale index lock behind" $stale_lock_exists -ne 0

rm -rf $test_repo
