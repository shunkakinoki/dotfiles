function _ompxeh_function --description "Run OMP headlessly with a prompted input"
  # Prompt for input and run OMP in print mode
  # Usage: ompxeh

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

  omp -p "$prompt"
end
