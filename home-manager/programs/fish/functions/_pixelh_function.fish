function _pixelh_function --description "Run Pi headlessly with the local Qwen model"
  # Prompt for input and run Pi in print mode with the local Qwen model
  # Usage: pixelh

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

  pi --model 'lmstudio/mlx-community/Qwen3.5-0.8B-OptiQ-4bit' -p "$prompt"
end
