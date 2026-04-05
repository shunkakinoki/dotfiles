function _gco_function --description "Checkout default branch and pull latest changes"
  set -l default_branch (git symbolic-ref refs/remotes/origin/HEAD | sed 's@^refs/remotes/origin/@@')
  git checkout $default_branch && git branch --set-upstream-to=origin/$default_branch $default_branch && git pull
end
