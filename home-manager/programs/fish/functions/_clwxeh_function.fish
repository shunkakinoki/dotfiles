function _clwxeh_function --description "Run Claude Code headlessly with a prompted input with git worktree integration"
  # Prompt for input and run Claude Code
  # Usage: clwxeh

  set -l prompt
  if test (count $argv) -gt 0
    set prompt (string join " " $argv)
  else
    read -P "Prompt: " prompt
  end

  if test -z "$prompt"
    echo "No prompt provided, aborting." >&2
    return 1
  end

  claude --dangerously-skip-permissions --worktree --print -- "$prompt"
end
