function _clxteh_function --description "Run Claude Code headlessly with a prompted input with tmux integration"
  # Prompt for input and run Claude Code
  # Usage: clxteh

  read -P "Prompt: " prompt
  if test -z "$prompt"
    echo "No prompt provided, aborting." >&2
    return 1
  end

  claude --dangerously-skip-permissions --worktree --tmux --print -- "$prompt"
end
