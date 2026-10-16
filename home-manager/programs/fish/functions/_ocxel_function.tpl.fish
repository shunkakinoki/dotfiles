function _ocxel_function --description "Run OpenCode with a free-form prompt using the local Qwen model"
  # Run OpenCode with a free-form prompt (spaces allowed) using the local Qwen model
  # Usage: ocxel [<prompt words...>]

  if test (count $argv) -gt 0; and contains -- "$argv[1]" --resume -r --continue -c
    if test (count $argv) -gt 1
      OPENCODE_CONFIG_CONTENT='{"model":"lmstudio/__QWEN_LOCAL__"}' opencode --session "$argv[2]"
    else
      OPENCODE_CONFIG_CONTENT='{"model":"lmstudio/__QWEN_LOCAL__"}' opencode --continue
    end
  else if test (count $argv) -eq 0
    OPENCODE_CONFIG_CONTENT='{"model":"lmstudio/__QWEN_LOCAL__"}' opencode
  else
    set -l prompt (string join " " -- $argv)
    opencode run "$prompt" -m 'lmstudio/__QWEN_LOCAL__'
  end
end
