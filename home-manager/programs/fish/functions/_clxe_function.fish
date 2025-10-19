function _clxe_function --description "Run Claude Code with a free-form prompt while skipping permissions"
  # Run Claude Code with a free-form prompt (spaces allowed) and bypass permission checks
  # Usage: clxe [<prompt words...>]

  if test (count $argv) -eq 0
    claude code --dangerously-skip-permissions
  else
    set -l prompt (string join " " -- $argv)
    claude code --dangerously-skip-permissions --print -- "$prompt"
  end
end
