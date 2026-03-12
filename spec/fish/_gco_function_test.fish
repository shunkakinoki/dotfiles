set fn ../../home-manager/programs/fish/functions
source $fn/_gco_function.fish

set call_log (mktemp)

function git
    echo $argv >> $call_log
    if test "$argv[1]" = symbolic-ref
        echo "refs/remotes/origin/main"
    end
end

_gco_function

@test "calls checkout on default branch" (grep -c "checkout main" $call_log) -ge 1
@test "calls pull" (grep -c "^pull" $call_log) -ge 1

rm -f $call_log
