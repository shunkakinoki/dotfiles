function _caxeh_function --description "Run Cursor Agent headlessly with a prompted input"
  # Run Cursor Agent headlessly
  # Usage: caxeh "prompt here" or caxeh (interactive)

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

  cursor-agent --force --print -- "$prompt"
end
