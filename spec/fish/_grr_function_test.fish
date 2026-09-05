set fn (status dirname)/../../home-manager/programs/fish/functions
source $fn/_git_index_lock_wait.fish
source $fn/_grr_function.fish

# --- Test: on main, clean, ff-able -> pull --ff-only ---

set call_log (mktemp)

function git
    echo $argv >> $call_log
    switch $argv[1]
        case symbolic-ref
            echo "refs/remotes/origin/main"
        case rev-parse
            echo "main"
        case diff
            return 0
        case merge-base
            return 0
        case fetch pull branch checkout reset
            return 0
    end
end

function sed
    echo "main"
end

function lsof
    return 1
end

function date
    if test "$argv[1]" = +%s
        echo 2000000000
    else
        echo "2026-07-16 12:00:00"
    end
end

function sleep
    echo "sleep $argv" >> $call_log
end

_grr_function --once
set exit_code $status

@test "pull: succeeds" $exit_code -eq 0
@test "pull: fetches default branch" (grep -c "fetch origin main" $call_log) -eq 1
@test "pull: uses ff-only pull" (grep -c "pull --ff-only origin main" $call_log) -eq 1
@test "pull: no hard reset" (grep -c "reset --hard" $call_log) -eq 0
@test "pull: does not sleep" (grep -c "sleep" $call_log) -eq 0

rm -f $call_log

# --- Test: on main, clean, diverged -> hard reset ---

set call_log (mktemp)

function git
    echo $argv >> $call_log
    switch $argv[1]
        case symbolic-ref
            echo "refs/remotes/origin/main"
        case rev-parse
            echo "main"
        case diff
            return 0
        case merge-base
            return 1
        case fetch pull branch checkout reset
            return 0
    end
end

function sed
    echo "main"
end

function date
    echo "2026-07-16 12:00:00"
end

_grr_function --once
set exit_code $status

@test "diverged: succeeds" $exit_code -eq 0
@test "diverged: hard resets" (grep -c "reset --hard origin/main" $call_log) -eq 1
@test "diverged: no pull" (grep -c "pull" $call_log) -eq 0

rm -f $call_log

# --- Test: not on main -> checkout + hard reset ---

set call_log (mktemp)

function git
    echo $argv >> $call_log
    switch $argv[1]
        case symbolic-ref
            echo "refs/remotes/origin/main"
        case rev-parse
            echo "feature"
        case diff
            return 0
        case fetch pull branch checkout reset
            return 0
    end
end

function sed
    echo "main"
end

function date
    echo "2026-07-16 12:00:00"
end

_grr_function --once
set exit_code $status

@test "other-branch: succeeds" $exit_code -eq 0
@test "other-branch: checks out main" (grep -c "checkout main" $call_log) -eq 1
@test "other-branch: hard resets" (grep -c "reset --hard origin/main" $call_log) -eq 1
@test "other-branch: no pull" (grep -c "pull" $call_log) -eq 0

rm -f $call_log

# --- Test: dirty working tree skips ---

set call_log (mktemp)
set err_log (mktemp)

function git
    echo $argv >> $call_log
    switch $argv[1]
        case symbolic-ref
            echo "refs/remotes/origin/main"
        case rev-parse
            echo "main"
        case diff
            return 1
        case fetch
            return 0
    end
end

function sed
    echo "main"
end

function date
    echo "2026-07-16 12:00:00"
end

_grr_function --once 2>$err_log
set exit_code $status

@test "dirty: non-zero exit" $exit_code -ne 0
@test "dirty: no pull" (grep -c "pull" $call_log) -eq 0
@test "dirty: no reset" (grep -c "reset" $call_log) -eq 0
@test "dirty: prints warning" (grep -c "dirty" $err_log) -ge 1

rm -f $call_log $err_log

# --- Test: unknown argument aborts ---

set err_log (mktemp)
_grr_function --bogus 2>$err_log
set exit_code $status

@test "bogus: exits 2" $exit_code -eq 2
@test "bogus: prints usage" (grep -c "usage: grr" $err_log) -ge 1

rm -f $err_log

# --- Test: fetch failure returns non-zero with --once ---

set call_log (mktemp)
set err_log (mktemp)

function git
    echo $argv >> $call_log
    if test "$argv[1]" = symbolic-ref
        echo "refs/remotes/origin/main"
    else if test "$argv[1]" = fetch
        return 1
    end
end

function sed
    echo "main"
end

function date
    echo "2026-07-16 12:00:00"
end

_grr_function --once 2>$err_log
set exit_code $status

@test "fail: non-zero exit" $exit_code -ne 0
@test "fail: no reset" (grep -c "reset" $call_log) -eq 0
@test "fail: prints warning" (grep -c "fetch failed" $err_log) -ge 1

rm -f $call_log $err_log

# --- Test: an unheld Git index lock is reaped before the cycle ---

set call_log (mktemp)
set err_log (mktemp)
set lock_path (mktemp)

function git
    echo $argv >> $call_log
    switch $argv[1]
        case symbolic-ref
            echo "refs/remotes/origin/main"
        case rev-parse
            if contains -- '--git-path' $argv
                echo $lock_path
            else
                echo "main"
            end
    end
end

function sed
    echo "main"
end

function date
    if test "$argv[1]" = +%s
        echo 2000000000
    else
        echo "2026-07-16 12:00:00"
    end
end

_grr_function --once 2>$err_log
set exit_code $status

@test "stale lock: succeeds" $exit_code -eq 0
@test "stale lock: fetches" (grep -c "fetch" $call_log) -eq 1
@test "stale lock: pulls" (grep -c "pull" $call_log) -eq 1
@test "stale lock: is removed" (test -e $lock_path; echo $status) -ne 0

rm -f $call_log $err_log $lock_path

# --- Test: a held Git index lock skips the cycle ---

set call_log (mktemp)
set err_log (mktemp)
set lock_path (mktemp)

function git
    echo $argv >> $call_log
    switch $argv[1]
        case symbolic-ref
            echo "refs/remotes/origin/main"
        case rev-parse
            if contains -- '--git-path' $argv
                echo $lock_path
            else
                echo "main"
            end
    end
end

function lsof
    echo 4242
end

function sed
    echo "main"
end

function date
    echo "2026-07-16 12:00:00"
end

_grr_function --once 2>$err_log
set exit_code $status

@test "held lock: returns non-zero" $exit_code -ne 0
@test "held lock: skips fetch" (grep -c "fetch" $call_log) -eq 0
@test "held lock: skips pull" (grep -c "pull" $call_log) -eq 0
@test "held lock: remains in place" (test -e $lock_path; echo $status) -eq 0
@test "held lock: prints warning" (grep -c "git index is locked" $err_log) -eq 1

rm -f $call_log $err_log $lock_path
