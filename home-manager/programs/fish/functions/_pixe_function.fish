function _pixe_function --description "Run Pi with a free-form prompt"
  # Run Pi with a free-form prompt (spaces allowed)
  # Usage: pixe [<prompt words...>]

  if test (count $argv) -eq 0
    pi --model 'cliproxyapi/glm-4.7'
  else
    set -l prompt (string join " " -- $argv)
    pi --model 'cliproxyapi/glm-4.7' "$prompt"
  end
end
