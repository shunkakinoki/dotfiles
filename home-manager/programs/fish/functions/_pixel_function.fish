function _pixel_function --description "Run Pi with a free-form prompt using the local Qwen model"
  # Run Pi with a free-form prompt (spaces allowed) using the local Qwen model
  # Usage: pixel [<prompt words...>]

  if test (count $argv) -gt 0; and contains -- "$argv[1]" --resume -r --continue -c
    pi --model 'lmstudio/mlx-community/Qwen3.5-0.8B-OptiQ-4bit' --resume $argv[2]
  else if test (count $argv) -eq 0
    pi --model 'lmstudio/mlx-community/Qwen3.5-0.8B-OptiQ-4bit'
  else
    set -l prompt (string join " " -- $argv)
    pi --model 'lmstudio/mlx-community/Qwen3.5-0.8B-OptiQ-4bit' "$prompt"
  end
end
