function _pixe_function --description "Run Pi agent with a free-form prompt"
  # Run Pi agent with a free-form prompt (spaces allowed)
  # Usage: pixe [<prompt words...>]

  if test (count $argv) -eq 0
    pi-agent -m 'openrouter-preset/@preset/__GLM_NONDOT__'
  else
    set -l prompt (string join " " -- $argv)
    pi-agent "$prompt" -m 'openrouter-preset/@preset/__GLM_NONDOT__'
  end
end
