function _cawxeh_function --description "Run Cursor Agent headlessly with a prompted input with git worktree integration"
  # Prompt for input and run Cursor Agent
  # Usage: cawxeh

  set -l prompt
  if test (count $argv) -gt 0
    set prompt (string join " " -- $argv)
  else
    read -P "Prompt: " prompt
  end

  if test -z "$prompt"
    echo "No prompt provided, aborting." >&2
    return 1
  end

  cursor-agent --force --worktree --print -- "$prompt"
end
