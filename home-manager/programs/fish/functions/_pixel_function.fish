function _pixel_function --description "Run Pi with a free-form prompt using the local Qwen model"
  # Run Pi with a free-form prompt (spaces allowed) using the local Qwen model
  # Usage: pixel [<prompt words...>]

  if test (count $argv) -gt 0; and contains -- "$argv[1]" --resume -r --continue -c
    pi --model 'lmstudio/qwen/qwen3.5-9b' --resume $argv[2]
  else if test (count $argv) -eq 0
    pi --model 'lmstudio/qwen/qwen3.5-9b'
  else
    set -l prompt (string join " " -- $argv)
    pi --model 'lmstudio/qwen/qwen3.5-9b' "$prompt"
  end
end
