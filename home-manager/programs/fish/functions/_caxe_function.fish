function _caxe_function --description "Run Cursor Agent with a free-form prompt while forcing command approval"
  # Run Cursor Agent with a free-form prompt (spaces allowed) and force-allow commands
  # Usage: caxe [--resume | -r] [<prompt words...>]

  if test (count $argv) -gt 0; and contains -- "$argv[1]" --resume -r --continue -c
    cursor-agent --force --resume $argv[2..]
  else if test (count $argv) -eq 0
    cursor-agent --force
  else
    set -l prompt (string join " " -- $argv)
    cursor-agent --force --print -- "$prompt"
  end
end
