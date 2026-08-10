function _ocxe_function --description "Run OpenCode with a free-form prompt"
  # Run OpenCode with a free-form prompt (spaces allowed)
  # Usage: ocxe [<prompt words...>]

  if test (count $argv) -gt 0; and contains -- "$argv[1]" --resume -r --continue -c
    if test (count $argv) -gt 1
      _caam_exec_function opencode -m 'cliproxyapi/main' --session "$argv[2]"
    else
      _caam_exec_function opencode -m 'cliproxyapi/main' --continue
    end
  else if test (count $argv) -eq 0
    _caam_exec_function opencode -m 'cliproxyapi/main'
  else
    set -l prompt (string join " " -- $argv)
    _caam_exec_function opencode run "$prompt" -m 'cliproxyapi/main'
  end
end
