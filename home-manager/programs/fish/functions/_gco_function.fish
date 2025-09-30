function _gco_function --description "Checkout default branch and pull latest changes"
  git checkout (git symbolic-ref refs/remotes/origin/HEAD | sed 's@^refs/remotes/origin/@@') && git pull
end
