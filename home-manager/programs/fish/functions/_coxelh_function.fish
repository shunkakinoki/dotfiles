function _coxelh_function --description "Run Codex headlessly with the local Qwen model"
  # Prompt for input and run Codex with the local Qwen model
  # Usage: coxelh

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

  codex exec --oss --local-provider lmstudio --model 'qwen3.5-0.8b-optiq' --full-auto -c model_reasoning_effort=minimal -- "$prompt"
end
