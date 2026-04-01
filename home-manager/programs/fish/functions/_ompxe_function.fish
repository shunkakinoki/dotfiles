function _ompxe_function --description "Run OMP with a free-form prompt"
  # Run OMP with a free-form prompt (spaces allowed)
  # Usage: ompxe [<prompt words...>]

  if test (count $argv) -gt 0; and contains -- "$argv[1]" --resume -r --continue -c
    omp --resume $argv[2]
  else if test (count $argv) -eq 0
    omp
  else
    set -l prompt (string join " " -- $argv)
    omp "$prompt"
  end
end
