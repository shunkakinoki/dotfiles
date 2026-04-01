function _cltxe_function --description "Run Claude Code with a free-form prompt while skipping permissions with tmux integration"
  # Run Claude Code with a free-form prompt (spaces allowed) and bypass permission checks
  # Usage: cltxe [<prompt words...>]

  if test (count $argv) -gt 0; and contains -- "$argv[1]" --resume -r --continue -c
    claude --dangerously-skip-permissions --worktree --tmux --resume $argv[2]
  else if test (count $argv) -eq 0
    claude --dangerously-skip-permissions --worktree --tmux
  else
    set -l prompt (string join " " -- $argv)
    claude --dangerously-skip-permissions --worktree --tmux --print -- "$prompt"
  end
end
