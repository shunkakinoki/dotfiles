function _ocxel_function --description "Run OpenCode with a free-form prompt using the local Gemma model"
  # Run OpenCode with a free-form prompt (spaces allowed) using the local Gemma model
  # Usage: ocxel [<prompt words...>]

  if test (count $argv) -gt 0; and contains -- "$argv[1]" --resume -r --continue -c
    if test (count $argv) -gt 1
      opencode -m 'lmstudio/__GEMMA__' --session "$argv[2]"
    else
      opencode -m 'lmstudio/__GEMMA__' --continue
    end
  else if test (count $argv) -eq 0
    opencode -m 'lmstudio/__GEMMA__'
  else
    set -l prompt (string join " " -- $argv)
    opencode run "$prompt" -m 'lmstudio/__GEMMA__'
  end
end
