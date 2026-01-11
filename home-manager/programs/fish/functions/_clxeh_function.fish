function _clxeh_function --description "Run Claude Code headlessly with a prompted input"
  # Prompt for input and run Claude Code
  # Usage: clxeh

  read -P "Prompt: " prompt
  if test -z "$prompt"
    echo "No prompt provided, aborting."
    return 1
  end

  claude --dangerously-skip-permissions --print -- "$prompt"
end
