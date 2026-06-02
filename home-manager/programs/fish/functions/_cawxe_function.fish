function _cawxe_function --description "Run Cursor Agent with a free-form prompt while forcing command approval with git worktree integration"
  # Run Cursor Agent with a free-form prompt (spaces allowed) and force-allow commands
  # Usage: cawxe [<prompt words...>]

  if test (count $argv) -gt 0; and contains -- "$argv[1]" --resume -r --continue -c
    cursor-agent --force --worktree --resume $argv[2]
  else if test (count $argv) -eq 0
    cursor-agent --force --worktree
  else
    set -l prompt (string join " " -- $argv)
    cursor-agent --force --worktree --print -- "$prompt"
  end
end
