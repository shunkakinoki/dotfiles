function _clxe_function
  # Run Codex with a free-form prompt (spaces allowed) using the local gpt-oss:120b model
  # Usage: clxe <prompt words...>

  if test (count $argv) -eq 0
    echo "Usage: clxe <prompt...>" >&2
    return 2
  end

  set -l prompt (string join " " -- $argv)
  codex --profile 'gpt-oss-120b' --full-auto -c model_reasoning_summary_format=experimental -- "$prompt"
end
