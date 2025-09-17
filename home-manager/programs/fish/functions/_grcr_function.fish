function _grcr_function
  # Determine the current branch; abort if detached HEAD
  set -l current_branch (git branch --show-current)
  if test -z "$current_branch"
    echo "Not on a branch; cannot reset to remote." >&2
    return 1
  end

  # Ensure we have the latest refs, then hard reset local branch to remote state
  git fetch origin $current_branch
  git reset --hard origin/$current_branch
end
