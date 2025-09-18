function _cxe_function
  # Run Codex with a free-form prompt (spaces allowed)
  # Usage: cxe <prompt words...>

  if test (count $argv) -eq 0
    echo "Usage: cxe <prompt...>" >&2
    return 2
  end

  set -l prompt (string join " " -- $argv)
  codex --model 'gpt-5-codex' --full-auto -c model_reasoning_summary_format=experimental -- "$prompt"
end
