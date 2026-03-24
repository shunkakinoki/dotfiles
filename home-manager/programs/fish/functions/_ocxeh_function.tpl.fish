function _ocxeh_function --description "Run OpenCode headlessly with a prompted input"
  # Prompt for input and run OpenCode
  # Usage: ocxeh

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

  opencode run "$prompt" -m 'cliproxyapi/__GLM__'
end
