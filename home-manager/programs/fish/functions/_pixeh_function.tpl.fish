function _pixeh_function --description "Run Pi headlessly with a prompted input"
  # Prompt for input and run Pi in print mode
  # Usage: pixeh

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

  pi --model 'cliproxyapi/__GLM__' -p "$prompt"
end
