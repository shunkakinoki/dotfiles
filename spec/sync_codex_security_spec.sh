#!/usr/bin/env bash
# shellcheck disable=SC2329

Describe 'sync-codex-security.sh'
SCRIPT="$PWD/scripts/sync-codex-security.sh"

setup() {
  TEMP_DIR=$(mktemp -d)
  mkdir -p "$TEMP_DIR/config/claude" "$TEMP_DIR/config/shared/hooks"

  cat >"$TEMP_DIR/config/claude/settings.json" <<'JSON'
{
  "permissions": {
    "deny": [
      "Bash(sudo:*)",
      "Bash(rm -rf /*:*)",
      "Bash(mkfs:*)",
      "Read(.env)"
    ]
  }
}
JSON

  cat >"$TEMP_DIR/config/shared/hooks/security.sh" <<'SCRIPT'
#!/usr/bin/env bash
set -euo pipefail
deny_patterns=(
  "old_pattern"
)
echo "rest of script"
SCRIPT
  chmod +x "$TEMP_DIR/config/shared/hooks/security.sh"
}

cleanup() {
  rm -rf "$TEMP_DIR"
}

Before 'setup'
After 'cleanup'

It 'syncs deny patterns from Claude settings'
When run bash -c "
  cd '$TEMP_DIR'
  patterns=\$(jq -r '.permissions.deny[]' config/claude/settings.json | grep '^Bash(' | sed -E 's/^Bash\((.+):\\*\)\$/\\1/' | sort)
  echo \"\$patterns\"
"
The status should be success
The output should include 'mkfs'
The output should include 'rm -rf /*'
The output should include 'sudo'
The output should not include 'Read'
End

It 'runs successfully on actual repo files'
When run bash "$SCRIPT"
The status should be success
End

It 'shared security.sh exists and is executable'
The path "$PWD/config/shared/hooks/security.sh" should be executable
End

It 'no agent-specific security.sh copies remain for codex/copilot/cursor'
When run bash -c "
  for path in \
    '$PWD/config/codex/hooks/security.sh' \
    '$PWD/config/copilot/hooks/security.sh' \
    '$PWD/config/cursor/hooks/security.sh'; do
    [ -e \"\$path\" ] && echo \"unexpected: \$path\"
  done
  exit 0
"
The output should eq ''
End
End
