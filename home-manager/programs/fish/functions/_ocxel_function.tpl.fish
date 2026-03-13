function _ocxel_function --description "Run OpenCode with a free-form prompt using the local Qwen model"
  # Run OpenCode with a free-form prompt (spaces allowed) using the local Qwen model
  # Usage: ocxel [<prompt words...>]

  if test (count $argv) -eq 0
    opencode -m 'lmstudio/__QWEN_LOCAL__'
  else
    set -l prompt (string join " " -- $argv)
    opencode run "$prompt" -m 'lmstudio/__QWEN_LOCAL__'
  end
end
