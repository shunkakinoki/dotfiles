function _pixel_function --description "Run Pi agent with a free-form prompt using the local Qwen model"
  # Run Pi agent with a free-form prompt (spaces allowed) using the local Qwen model
  # Usage: pixel [<prompt words...>]

  if test (count $argv) -eq 0
    pi-agent -m 'lmstudio/__QWEN_LOCAL__'
  else
    set -l prompt (string join " " -- $argv)
    pi-agent "$prompt" -m 'lmstudio/__QWEN_LOCAL__'
  end
end
