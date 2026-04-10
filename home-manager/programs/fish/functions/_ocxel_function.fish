function _ocxel_function --description "Run OpenCode with a free-form prompt using the local Gemma model"
  # Run OpenCode with a free-form prompt (spaces allowed) using the local Gemma model
  # Usage: ocxel [<prompt words...>]

  if test (count $argv) -gt 0; and contains -- "$argv[1]" --resume -r --continue -c
    if test (count $argv) -gt 1
      opencode -m 'lmstudio/mlx-community/gemma-4-e4b-it-4bit' --session "$argv[2]"
    else
      opencode -m 'lmstudio/mlx-community/gemma-4-e4b-it-4bit' --continue
    end
  else if test (count $argv) -eq 0
    opencode -m 'lmstudio/mlx-community/gemma-4-e4b-it-4bit'
  else
    set -l prompt (string join " " -- $argv)
    opencode run "$prompt" -m 'lmstudio/mlx-community/gemma-4-e4b-it-4bit'
  end
end
