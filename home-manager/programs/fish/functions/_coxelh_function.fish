function _coxelh_function --description "Run Codex headlessly with the local Qwen model"
  # Prompt for input and run Codex with the local Qwen model
  # Usage: coxelh

  read -P "Prompt: " prompt
  if test -z "$prompt"
    echo "No prompt provided, aborting." >&2
    return 1
  end

  codex exec --oss --local-provider lmstudio --model 'qwen/qwen3.5-9b' --full-auto -c model_reasoning_effort=minimal -- "$prompt"
end
