set fn (status dirname)/../../home-manager/programs/fish/functions
source $fn/_grs_function.fish

# --- Test: merged clean branch resets to origin ---

set call_log (mktemp)

function git
    echo $argv >> $call_log
    if test "$argv[1]" = symbolic-ref
        echo "refs/remotes/origin/main"
    else if test "$argv[1]" = diff
        return 0
    else if test "$argv[1]" = merge-base
        return 0
    end
end

function sed
    echo "main"
end

_grs_function

@test "fetches origin" (grep -c "fetch origin" $call_log) -ge 1
@test "checks merge status" (grep -c "merge-base" $call_log) -ge 1
@test "resets to origin default branch" (grep -c "reset --hard origin/main" $call_log) -ge 1
@test "sets upstream tracking" (grep -c "branch --set-upstream-to=origin/main" $call_log) -ge 1

rm -f $call_log

# --- Test: dirty working tree aborts ---

set call_log (mktemp)
set err_log (mktemp)

function git
    echo $argv >> $call_log
    if test "$argv[1]" = symbolic-ref
        echo "refs/remotes/origin/main"
    else if test "$argv[1]" = diff
        return 1
    end
end

function sed
    echo "main"
end

_grs_function 2>$err_log
set exit_code $status

@test "dirty: aborts with error" $exit_code -eq 1
@test "dirty: no fetch" (grep -c "fetch" $call_log) -eq 0
@test "dirty: no reset" (grep -c "reset" $call_log) -eq 0
@test "dirty: prints warning" (grep -c "dirty" $err_log) -ge 1

rm -f $call_log $err_log

# --- Test: unmerged branch aborts ---

set call_log (mktemp)
set err_log (mktemp)

function git
    echo $argv >> $call_log
    if test "$argv[1]" = symbolic-ref
        echo "refs/remotes/origin/main"
    else if test "$argv[1]" = diff
        return 0
    else if test "$argv[1]" = merge-base
        return 1
    end
end

function sed
    echo "main"
end

_grs_function 2>$err_log
set exit_code $status

@test "unmerged: aborts with error" $exit_code -eq 1
@test "unmerged: no reset" (grep -c "reset" $call_log) -eq 0
@test "unmerged: prints warning" (grep -c "not merged" $err_log) -ge 1

rm -f $call_log $err_log
