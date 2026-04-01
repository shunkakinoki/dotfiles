function _ocxe_function --description "Run OpenCode with a free-form prompt"
  # Run OpenCode with a free-form prompt (spaces allowed)
  # Usage: ocxe [<prompt words...>]

  if test (count $argv) -gt 0; and contains -- "$argv[1]" --resume -r --continue -c
    if test (count $argv) -gt 1
      opencode -m 'cliproxyapi/__GLM__' --session "$argv[2]"
    else
      opencode -m 'cliproxyapi/__GLM__' --continue
    end
  else if test (count $argv) -eq 0
    opencode -m 'cliproxyapi/__GLM__'
  else
    set -l prompt (string join " " -- $argv)
    opencode run "$prompt" -m 'cliproxyapi/__GLM__'
  end
end
