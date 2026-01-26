function _ocxeh_function --description "Run OpenCode headlessly with GLM-4.7"
  # Prompt for input and run OpenCode
  # Usage: ocxeh

  read -P "Prompt: " prompt
  if test -z "$prompt"
    echo "No prompt provided, aborting." >&2
    return 1
  end

  opencode run "$prompt" -m 'cliproxyapi/glm-4.7'
end
