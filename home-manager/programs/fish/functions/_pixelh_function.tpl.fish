function _pixelh_function --description "Run Pi headlessly with the local Qwen model"
  # Prompt for input and run Pi in print mode with the local Qwen model
  # Usage: pixelh

  read -P "Prompt: " prompt
  if test -z "$prompt"
    echo "No prompt provided, aborting." >&2
    return 1
  end

  pi --model 'lmstudio/__QWEN_LOCAL__' -p "$prompt"
end
