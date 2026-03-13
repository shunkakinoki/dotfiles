function _ocxe_function --description "Run OpenCode with a free-form prompt"
  # Run OpenCode with a free-form prompt (spaces allowed)
  # Usage: ocxe [<prompt words...>]

  if test (count $argv) -eq 0
    opencode -m 'cliproxyapi/__GLM__'
  else
    set -l prompt (string join " " -- $argv)
    opencode run "$prompt" -m 'cliproxyapi/__GLM__'
  end
end
