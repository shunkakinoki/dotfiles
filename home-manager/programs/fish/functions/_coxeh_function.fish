function _coxeh_function --description "Run Codex headlessly with a prompted input"
  # Prompt for input and run Codex
  # Usage: coxeh

  read -P "Prompt: " prompt
  if test -z "$prompt"
    echo "No prompt provided, aborting." >&2
    return 1
  end

  codex exec --model 'gpt-5.2-codex' --full-auto -c model_reasoning_summary_format=experimental -- "$prompt"
end
