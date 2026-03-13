function _pixeh_function --description "Run Pi headlessly with a prompted input"
  # Prompt for input and run Pi in print mode
  # Usage: pixeh

  read -P "Prompt: " prompt
  if test -z "$prompt"
    echo "No prompt provided, aborting." >&2
    return 1
  end

  pi --model 'cliproxyapi/glm-4.7' -p "$prompt"
end
