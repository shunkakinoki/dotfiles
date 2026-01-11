function _ocxe_function --description "Run OpenCode with GLM-4.7 via OpenRouter"
  # Run OpenCode with a free-form prompt (spaces allowed) using GLM-4.7
  # Usage: ocxe [<prompt words...>]

  if test (count $argv) -eq 0
    opencode -m 'openrouter-preset/glm-4-7'
  else
    set -l prompt (string join " " -- $argv)
    opencode run "$prompt" -m 'openrouter-preset/glm-4-7'
  end
end
