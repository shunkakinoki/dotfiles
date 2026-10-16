function _ocxel_function --description "Run OpenCode with a free-form prompt using the local Qwen model"
  # Run OpenCode with a free-form prompt (spaces allowed) using the local Qwen model
  # Usage: ocxel [<prompt words...>]

  # The OpenCode 2 TUI takes no model flag; its private server reads the model from this config overlay.
  set -lx OPENCODE_CONFIG_CONTENT '{"model":"lmstudio/qwen3.5-0.8b-optiq"}'

  if test (count $argv) -gt 0; and contains -- "$argv[1]" --resume -r --continue -c
    if test (count $argv) -gt 1
      opencode --standalone --session "$argv[2]"
    else
      opencode --standalone --continue
    end
  else if test (count $argv) -eq 0
    opencode --standalone
  else
    set -l prompt (string join " " -- $argv)
    opencode run "$prompt" -m 'lmstudio/qwen3.5-0.8b-optiq'
  end
end
