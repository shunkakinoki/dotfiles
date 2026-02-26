set fn (status dirname)/../../home-manager/programs/fish/functions
source $fn/_grcr_function.fish

# ── detached HEAD → error ─────────────────────────────────
function git
    if test "$argv[1]" = branch
        echo ""
    end
end

@test "detached HEAD prints error" (string match -q "*Not on a branch*" (_grcr_function 2>&1); echo $status) = 0
@test "detached HEAD returns 1" (_grcr_function 2>/dev/null; echo $status) = 1

# ── on a branch → fetch + reset ──────────────────────────
set call_log (mktemp)
function git
    if test "$argv[1]" = branch
        echo feature-branch
    else
        echo $argv >> $call_log
    end
end

_grcr_function

@test "fetches current branch" (grep -c "fetch origin feature-branch" $call_log) -ge 1
@test "resets hard to remote" (grep -c "reset --hard origin/feature-branch" $call_log) -ge 1

rm -f $call_log
