set fn (status dirname)/../../home-manager/programs/fish/functions
source $fn/_grs_function.fish

set call_log (mktemp)

function git
    echo $argv >> $call_log
    if test "$argv[1]" = symbolic-ref
        echo "refs/remotes/origin/main"
    end
end

function sed
    echo "main"
end

_grs_function

@test "fetches origin" (grep -c "fetch origin" $call_log) -ge 1
@test "resets to origin default branch" (grep -c "reset --hard origin/main" $call_log) -ge 1

rm -f $call_log
