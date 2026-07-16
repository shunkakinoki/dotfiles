set fn (status dirname)/../../home-manager/programs/fish/functions
source $fn/_grf_function.fish

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

function date
    echo "2026-07-16 12:00:00"
end

function sleep
    echo "sleep $argv" >> $call_log
end

_grf_function --once
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

_grf_function --once
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

_grf_function --once
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

_grf_function --once 2>$err_log
set exit_code $status

@test "dirty: non-zero exit" $exit_code -ne 0
@test "dirty: no pull" (grep -c "pull" $call_log) -eq 0
@test "dirty: no reset" (grep -c "reset" $call_log) -eq 0
@test "dirty: prints warning" (grep -c "dirty" $err_log) -ge 1

rm -f $call_log $err_log

# --- Test: unknown argument aborts ---

set err_log (mktemp)
_grf_function --bogus 2>$err_log
set exit_code $status

@test "bogus: exits 2" $exit_code -eq 2
@test "bogus: prints usage" (grep -c "usage: grf" $err_log) -ge 1

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

_grf_function --once 2>$err_log
set exit_code $status

@test "fail: non-zero exit" $exit_code -ne 0
@test "fail: no reset" (grep -c "reset" $call_log) -eq 0
@test "fail: prints warning" (grep -c "fetch failed" $err_log) -ge 1

rm -f $call_log $err_log
