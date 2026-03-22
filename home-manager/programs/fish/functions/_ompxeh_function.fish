function _ompxeh_function --description "Run OMP headlessly with a prompted input"
  # Prompt for input and run OMP in print mode
  # Usage: ompxeh

  read -P "Prompt: " prompt
  if test -z "$prompt"
    echo "No prompt provided, aborting." >&2
    return 1
  end

  omp -p "$prompt"
end
