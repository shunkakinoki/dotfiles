set fn (status dirname)/../../home-manager/programs/fish/functions
source $fn/_git_index_lock_wait.fish

set test_repo (mktemp -d)
git -C $test_repo init --quiet

pushd $test_repo >/dev/null
_git_index_lock_wait 0
set unlocked_status $status

function lsof
    return 1
end

touch .git/index.lock
_git_index_lock_wait 0 2>/dev/null
set stale_status $status
set stale_lock_exists (test -e .git/index.lock; echo $status)

function sleep
    rm -f .git/index.lock
end

touch .git/index.lock
_git_index_lock_wait 1
set waited_status $status
set waited_lock_exists (test -e .git/index.lock; echo $status)

functions --erase sleep

function lsof
    echo 4242
end

touch .git/index.lock
_git_index_lock_wait 0 2>/dev/null
set held_status $status
set held_lock_exists (test -e .git/index.lock; echo $status)
popd >/dev/null

@test "returns success when no index lock exists" $unlocked_status -eq 0
@test "removes an unheld stale index lock" $stale_status -eq 0
@test "leaves no stale index lock behind" $stale_lock_exists -ne 0
@test "returns success when a waited-on lock clears" $waited_status -eq 0
@test "leaves no cleared lock behind" $waited_lock_exists -ne 0
@test "returns failure when the lock has a live holder" $held_status -ne 0
@test "preserves a lock with a live holder" $held_lock_exists -eq 0

rm -rf $test_repo
