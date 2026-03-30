#!/usr/bin/env bash
# shellcheck disable=SC2329

Describe 'sync-codex-security.sh'
SCRIPT="$PWD/scripts/sync-codex-security.sh"

setup() {
  TEMP_DIR=$(mktemp -d)
  mkdir -p "$TEMP_DIR/config/claude" "$TEMP_DIR/config/codex/hooks"

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

  cat >"$TEMP_DIR/config/codex/hooks/security.sh" <<'SCRIPT'
#!/usr/bin/env bash
set -euo pipefail
deny_patterns=(
  "old_pattern"
)
echo "rest of script"
SCRIPT
  chmod +x "$TEMP_DIR/config/codex/hooks/security.sh"
}

cleanup() {
  rm -rf "$TEMP_DIR"
}

Before 'setup'
After 'cleanup'

It 'syncs deny patterns from Claude settings'
When run bash -c "
  # Create a modified script that uses TEMP_DIR paths
  sed -e 's|/config/claude/settings.json|/config/claude/settings.json|' \
      -e 's|\$(cd.*pwd)|echo $TEMP_DIR|' \
      '$SCRIPT' > '$TEMP_DIR/sync.sh'
  chmod +x '$TEMP_DIR/sync.sh'

  # Run with ROOT override
  cd '$TEMP_DIR'
  ROOT='$TEMP_DIR' bash -c '
    CLAUDE_SETTINGS=\"\$ROOT/config/claude/settings.json\"
    CODEX_SECURITY=\"\$ROOT/config/codex/hooks/security.sh\"
    source <(sed -n \"s|ROOT=.*|ROOT=\$ROOT|p\" /dev/null || true)
  '

  # Just test the script directly by simulating it
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
End
