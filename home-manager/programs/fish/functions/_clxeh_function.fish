function _clxeh_function --description "Run Claude Code headlessly with a prompted input"
  # Run Claude Code headlessly
  # Usage: clxeh "prompt here" or clxeh (interactive)

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

  claude --dangerously-skip-permissions --print -- "$prompt"
end
