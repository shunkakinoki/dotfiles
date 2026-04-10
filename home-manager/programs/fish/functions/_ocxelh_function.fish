function _ocxelh_function --description "Run OpenCode headlessly with the local Gemma model"
  # Prompt for input and run OpenCode with the local Gemma model
  # Usage: ocxelh

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

  opencode run "$prompt" -m 'lmstudio/lmstudio-community/gemma-4-e4b-it'
end
