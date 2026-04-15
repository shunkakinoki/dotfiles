function _coxeh_function --description "Run Codex headlessly with a prompted input"
  # Prompt for input and run Codex
  # Usage: coxeh

  set -l prompt
  if test (count $argv) -gt 0
    set prompt (string join " " $argv)
  else
    read -P "Prompt: " prompt
  end

  if test -z "$prompt"
    echo "No prompt provided, aborting." >&2
    return 1
  end

  codex --dangerously-bypass-approvals-and-sandbox exec --model '__GPT__' -c model_reasoning_summary_format=experimental -- "$prompt"
end
