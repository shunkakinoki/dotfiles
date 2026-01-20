function _coxel_function --description "Run Codex with a free-form prompt using the local glm-4.7-flash model"
  # Run Codex with a free-form prompt (spaces allowed) using the local glm-4.7-flash model
  # Usage: cxel [<prompt words...>]

  if test (count $argv) -eq 0
    codex --profile 'glm-4.7-flash' --full-auto -c model_reasoning_summary_format=experimental
  else
    set -l prompt (string join " " -- $argv)
    codex exec --profile 'glm-4.7-flash' --full-auto -c model_reasoning_summary_format=experimental -- "$prompt"
  end
end
