function _ocxelh_function --description "Run OpenCode headlessly with the local Qwen model"
  # Prompt for input and run OpenCode with the local Qwen model
  # Usage: ocxelh

  read -P "Prompt: " prompt
  if test -z "$prompt"
    echo "No prompt provided, aborting." >&2
    return 1
  end

  opencode run "$prompt" -m 'lmstudio/__QWEN_LOCAL__'
end
