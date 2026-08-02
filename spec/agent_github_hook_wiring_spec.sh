#!/usr/bin/env bash

Describe 'shared GitHub guardrail wiring'

verify_wiring() {
  local config hook
  for config in \
    config/codex/hooks.json \
    config/claude/settings.json \
    config/cursor/hooks.json \
    config/copilot/config.json \
    config/grok/plugin/hooks/hooks.json; do
    for hook in block-git-push.sh block-gh-settings.sh; do
      if ! grep -Fq "config/shared/hooks/$hook" "$config"; then
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
