function _coxe_function --description "Run Codex with a free-form prompt"
  # Run Codex with a free-form prompt (spaces allowed)
  # Usage: cxe [<prompt words...>]

  if test (count $argv) -gt 0; and contains -- "$argv[1]" --resume -r --continue -c
    codex --dangerously-bypass-approvals-and-sandbox resume $argv[2]
  else if test (count $argv) -eq 0
    codex --dangerously-bypass-approvals-and-sandbox --model '__GPT__' -c model_reasoning_summary_format=experimental
  else
    set -l prompt (string join " " -- $argv)
    codex --dangerously-bypass-approvals-and-sandbox exec --model '__GPT__' -c model_reasoning_summary_format=experimental -- "$prompt"
  end
end
