function _ocxe_function --description "Run OpenCode with a free-form prompt"
  # Run OpenCode with a free-form prompt (spaces allowed)
  # Usage: ocxe [<prompt words...>]

  # The OpenCode 2 TUI takes no model flag; its private server reads the model from this config overlay.
  set -lx OPENCODE_CONFIG_CONTENT '{"model":"shunkakinoki/deepseek-v4.1-flash"}'

  if test (count $argv) -gt 0; and contains -- "$argv[1]" --resume -r --continue -c
    if test (count $argv) -gt 1
      _caam_exec_function opencode --standalone --session "$argv[2]"
    else
      _caam_exec_function opencode --standalone --continue
    end
  else if test (count $argv) -eq 0
    _caam_exec_function opencode --standalone
  else
    set -l prompt (string join " " -- $argv)
    _caam_exec_function opencode run "$prompt" -m 'shunkakinoki/deepseek-v4.1-flash'
  end
end
