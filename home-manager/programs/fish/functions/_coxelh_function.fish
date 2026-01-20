function _coxelh_function --description "Run Codex headlessly with local glm-4.7-flash model"
  # Prompt for input and run Codex with local model
  # Usage: coxelh

  read -P "Prompt: " prompt
  if test -z "$prompt"
    echo "No prompt provided, aborting." >&2
    return 1
  end

  codex exec --profile 'glm-4.7-flash' --full-auto -c model_reasoning_summary_format=experimental -- "$prompt"
end
