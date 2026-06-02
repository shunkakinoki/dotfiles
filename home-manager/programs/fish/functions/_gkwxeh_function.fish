function _gkwxeh_function --description "Run Grok headlessly with a prompted input with git worktree integration"
  # Prompt for input and run Grok
  # Usage: gkwxeh

  set -l prompt
  if test (count $argv) -gt 0
    set prompt (string join " " $argv)
  else
    read -P "Prompt: " prompt
  end

  if test -z "$prompt"
    echo "No prompt provided, aborting." >&2
    return 1
  end

  grok --always-approve --worktree --single "$prompt"
end
