function _coxel_function --description "Run Codex with a free-form prompt using the local Gemma model"
  # Run Codex with a free-form prompt (spaces allowed) using the local Gemma model
  # Usage: cxel [<prompt words...>]

  if test (count $argv) -gt 0; and contains -- "$argv[1]" --resume -r --continue -c
    codex resume $argv[2]
  else if test (count $argv) -eq 0
    codex --oss --local-provider lmstudio --model 'mlx-community/gemma-4-e4b-it-4bit' --full-auto -c model_reasoning_effort=minimal
  else
    set -l prompt (string join " " -- $argv)
    codex exec --oss --local-provider lmstudio --model 'mlx-community/gemma-4-e4b-it-4bit' --full-auto -c model_reasoning_effort=minimal -- "$prompt"
  end
end
