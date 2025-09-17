function _grco_function
  # Determine the default branch (e.g., main or master) from origin/HEAD
  set -l default_branch (git symbolic-ref refs/remotes/origin/HEAD | sed 's@^refs/remotes/origin/@@')

  # Ensure we have the latest refs, then hard reset local default to remote
  git fetch origin $default_branch
  git checkout $default_branch
  git reset --hard origin/$default_branch
end
