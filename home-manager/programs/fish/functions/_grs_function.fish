function _grs_function --description "Reset to origin default branch (safe: aborts if unmerged)"
    set -l default_branch (git symbolic-ref refs/remotes/origin/HEAD | sed 's@^refs/remotes/origin/@@')
    git fetch origin

    if not git merge-base --is-ancestor HEAD origin/$default_branch
        echo "grs: current branch is not merged into origin/$default_branch, aborting." >&2
        return 1
    end

    git reset --hard origin/$default_branch
end
