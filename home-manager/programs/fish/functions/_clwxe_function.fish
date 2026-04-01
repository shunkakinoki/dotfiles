function _clwxe_function --description "Run Claude Code with a free-form prompt while skipping permissions with git worktree integration"
  # Run Claude Code with a free-form prompt (spaces allowed) and bypass permission checks
  # Usage: clwxe [<prompt words...>]

  if test (count $argv) -gt 0; and contains -- "$argv[1]" --resume -r --continue -c
    claude --dangerously-skip-permissions --worktree --resume $argv[2]
  else if test (count $argv) -eq 0
    claude --dangerously-skip-permissions --worktree
  else
    set -l prompt (string join " " -- $argv)
    claude --dangerously-skip-permissions --worktree --print -- "$prompt"
  end
end
