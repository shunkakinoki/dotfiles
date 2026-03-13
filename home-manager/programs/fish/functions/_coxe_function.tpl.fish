function _coxe_function --description "Run Codex with a free-form prompt"
  # Run Codex with a free-form prompt (spaces allowed)
  # Usage: cxe [<prompt words...>]

  if test (count $argv) -eq 0
    codex --model '__GPT__' --full-auto -c model_reasoning_summary_format=experimental
  else
    set -l prompt (string join " " -- $argv)
    codex exec --model '__GPT__' --full-auto -c model_reasoning_summary_format=experimental -- "$prompt"
  end
end
