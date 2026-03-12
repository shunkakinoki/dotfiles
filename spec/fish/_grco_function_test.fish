set fn ../../home-manager/programs/fish/functions
source $fn/_grco_function.fish

set call_log (mktemp)

function git
    echo $argv >> $call_log
    if test "$argv[1]" = symbolic-ref
        echo "refs/remotes/origin/main"
    end
end

_grco_function

@test "fetches default branch" (grep -c "fetch origin main" $call_log) -ge 1
@test "checks out default branch" (grep -c "checkout main" $call_log) -ge 1
@test "resets hard to remote" (grep -c "reset --hard origin/main" $call_log) -ge 1

rm -f $call_log
