#!/usr/bin/env bash

Describe 'shared GitHub guardrail wiring'

registered_hook_commands() {
  local config="$1"
  case "$config" in
  config/codex/hooks.json | config/claude/settings.json)
    jq -r '.hooks.PreToolUse[] | select(.matcher == "Bash") | .hooks[]?.command' "$config"
    ;;
  config/cursor/hooks.json)
    jq -r '.hooks.beforeShellExecution[]?.command' "$config"
    ;;
  config/copilot/config.json)
    jq -r '.hooks.preToolUse[]?.command' "$config"
    ;;
  config/grok/plugin/hooks/hooks.json)
    jq -r '.hooks.PreToolUse[] | select(.matcher | test("(^|\\|)Bash($|\\|)")) | .hooks[]?.command' "$config"
    ;;
  esac
}

verify_wiring() {
  local config hook
  for config in \
    config/codex/hooks.json \
    config/claude/settings.json \
    config/cursor/hooks.json \
    config/copilot/config.json \
    config/grok/plugin/hooks/hooks.json; do
    for hook in block-git-push.sh block-gh-settings.sh; do
      if ! registered_hook_commands "$config" | grep -Fqx "\$HOME/dotfiles/config/shared/hooks/$hook"; then
        printf 'missing %s in %s\n' "$hook" "$config" >&2
        return 1
      fi
    done
  done
}

It 'keeps both hooks registered for Codex Claude Cursor Copilot and Grok'
When call verify_wiring
The status should be success
End
End
