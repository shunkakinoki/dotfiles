function _grs_function --description "Reset to origin default branch"
    git fetch origin && git reset --hard origin/(git symbolic-ref refs/remotes/origin/HEAD | sed 's@^refs/remotes/origin/@@')
end
