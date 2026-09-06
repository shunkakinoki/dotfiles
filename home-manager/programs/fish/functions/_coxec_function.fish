function _coxec_function --description "Run Codex with a free-form prompt through CLIProxyAPI"
  # Run Codex with a free-form prompt (spaces allowed) on the cliproxy profile,
  # which carries the model and provider, so no caam profile is consumed.
  # Usage: coxec [<prompt words...>]

  if test (count $argv) -gt 0; and contains -- "$argv[1]" --resume -r --continue -c
    codex --dangerously-bypass-approvals-and-sandbox resume $argv[2]
  else if test (count $argv) -eq 0
    codex --dangerously-bypass-approvals-and-sandbox --profile cliproxy -c model_reasoning_summary_format=experimental
  else
    set -l prompt (string join " " -- $argv)
    codex --dangerously-bypass-approvals-and-sandbox exec --profile cliproxy -c model_reasoning_summary_format=experimental -- "$prompt"
  end
end
