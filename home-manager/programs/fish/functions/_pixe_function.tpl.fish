function _pixe_function --description "Run Pi with a free-form prompt"
  # Run Pi with a free-form prompt (spaces allowed)
  # Usage: pixe [<prompt words...>]

  if test (count $argv) -eq 0
    pi --model 'cliproxyapi/__GLM__'
  else
    set -l prompt (string join " " -- $argv)
    pi --model 'cliproxyapi/__GLM__' "$prompt"
  end
end
