function _cltxeh_function --description "Run Claude Code headlessly with a prompted input withtmux integration"
  # Prompt for input and run Claude Code
  # Usage: cltxeh

  read -P "Prompt: " prompt
  if test -z "$prompt"
    echo "No prompt provided, aborting." >&2
    return 1
  end

  claude --dangerously-skip-permissions --worktree --tmux --print -- "$prompt"
end
