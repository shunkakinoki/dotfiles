set fn (status dirname)/../../home-manager/programs/fish/functions
source $fn/_cliproxyapi_quota_function.fish

set log (mktemp)
function cliproxy-quota
    echo "cliproxy-quota $argv" >>$log
    return 3
end

_cliproxyapi_quota_function
set rc $status
@test "defaults to the status view" (cat $log) = "cliproxy-quota "
@test "passes the exit status through" $rc = 3

echo -n >$log
_cliproxyapi_quota_function resets --json codex
@test "passes subcommands and arguments through" (cat $log) = "cliproxy-quota resets --json codex"

rm -f $log
