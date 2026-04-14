function _coxe_function --description "Run Codex with a free-form prompt"
  # Run Codex with a free-form prompt (spaces allowed)
  # Usage: cxe [<prompt words...>]
  set -l bypass_flag --dangerously-bypass-approvals-and-sandbox

  if test (count $argv) -gt 0; and contains -- "$argv[1]" --resume -r --continue -c
    codex $bypass_flag resume $argv[2]
  else if test (count $argv) -eq 0
    codex $bypass_flag --model 'gpt-5.4' --full-auto -c model_reasoning_summary_format=experimental
  else
    set -l prompt (string join " " -- $argv)
    codex $bypass_flag exec --model 'gpt-5.4' --full-auto -c model_reasoning_summary_format=experimental -- "$prompt"
  end
end
