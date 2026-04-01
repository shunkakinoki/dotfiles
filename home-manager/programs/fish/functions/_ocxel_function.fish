function _ocxel_function --description "Run OpenCode with a free-form prompt using the local Qwen model"
  # Run OpenCode with a free-form prompt (spaces allowed) using the local Qwen model
  # Usage: ocxel [<prompt words...>]

  if test (count $argv) -gt 0; and contains -- "$argv[1]" --resume -r --continue -c
    if test (count $argv) -gt 1
      opencode -m 'lmstudio/qwen/qwen3.5-9b' --session "$argv[2]"
    else
      opencode -m 'lmstudio/qwen/qwen3.5-9b' --continue
    end
  else if test (count $argv) -eq 0
    opencode -m 'lmstudio/qwen/qwen3.5-9b'
  else
    set -l prompt (string join " " -- $argv)
    opencode run "$prompt" -m 'lmstudio/qwen/qwen3.5-9b'
  end
end
