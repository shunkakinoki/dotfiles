function _coxelh_function --description "Run Codex headlessly with local gpt-oss:120b model"
  # Prompt for input and run Codex with local model
  # Usage: coxelh

  read -P "Prompt: " prompt
  if test -z "$prompt"
    echo "No prompt provided, aborting." >&2
    return 1
  end

  codex --profile 'gpt-oss-120b' --full-auto -c model_reasoning_summary_format=experimental -- "$prompt"
end
