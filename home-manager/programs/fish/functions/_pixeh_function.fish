function _pixeh_function --description "Run Pi agent headlessly with GLM-4.7"
  # Prompt for input and run Pi agent
  # Usage: pixeh

  read -P "Prompt: " prompt
  if test -z "$prompt"
    echo "No prompt provided, aborting." >&2
    return 1
  end

  pi-agent "$prompt" -m 'openrouter-preset/@preset/glm-4-7'
end
