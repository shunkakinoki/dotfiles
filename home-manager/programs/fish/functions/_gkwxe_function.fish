function _gkwxe_function --description "Run Grok with a free-form prompt while auto-approving tools with git worktree integration"
  # Run Grok with a free-form prompt (spaces allowed) and auto-approve all tool executions
  # Usage: gkwxe [<prompt words...>]

  if test (count $argv) -gt 0; and contains -- "$argv[1]" --resume -r --continue -c
    grok --always-approve --worktree --resume $argv[2..]
  else if test (count $argv) -eq 0
    grok --always-approve --worktree
  else
    set -l prompt (string join " " -- $argv)
    grok --always-approve --worktree --single "$prompt"
  end
end
