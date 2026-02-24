function _clxwe_function --description "Run Claude Code with a free-form prompt while skipping permissions with git worktree integration"
  # Run Claude Code with a free-form prompt (spaces allowed) and bypass permission checks
  # Usage: clxwe [<prompt words...>]

  if test (count $argv) -eq 0
    claude --dangerously-skip-permissions --yes --worktree
  else
    set -l prompt (string join " " -- $argv)
    claude --dangerously-skip-permissions --yes --worktree --print -- "$prompt"
  end
end
