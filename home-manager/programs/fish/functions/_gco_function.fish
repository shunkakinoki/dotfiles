function _gco_function --description "Checkout default branch and pull latest changes"
  set -l default_branch (git symbolic-ref refs/remotes/origin/HEAD | sed 's@^refs/remotes/origin/@@')
  _git_index_lock_wait 30; or return 1
  git checkout $default_branch && git branch --set-upstream-to=origin/$default_branch $default_branch && git pull
end
