function _grxe_function --description "Run Grok with a free-form prompt while auto-approving tools"
  # Run Grok with a free-form prompt (spaces allowed) and auto-approve all tool executions
  # Usage: grxe [--resume | -r] [<prompt words...>]

  if test (count $argv) -gt 0; and contains -- "$argv[1]" --resume -r --continue -c
    grok --always-approve --resume $argv[2..]
  else if test (count $argv) -eq 0
    grok --always-approve
  else
    set -l prompt (string join " " -- $argv)
    grok --always-approve --single "$prompt"
  end
end
