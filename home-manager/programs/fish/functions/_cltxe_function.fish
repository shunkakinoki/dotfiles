function _clxte_function --description "Run Claude Code with a free-form prompt while skipping permissions with tmux integration"
  # Run Claude Code with a free-form prompt (spaces allowed) and bypass permission checks
  # Usage: clxte [<prompt words...>]

  if test (count $argv) -eq 0
    claude --dangerously-skip-permissions --worktree --tmux
  else
    set -l prompt (string join " " -- $argv)
    claude --dangerously-skip-permissions --worktree --tmux --print -- "$prompt"
  end
end
