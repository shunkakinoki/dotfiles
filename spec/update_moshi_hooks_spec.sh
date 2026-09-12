#!/usr/bin/env bash
# shellcheck disable=SC2016,SC2329,SC2034

Describe 'update-moshi-hooks.sh'
SCRIPT="$PWD/scripts/update-moshi-hooks.sh"

Describe 'script structure'
It 'exists and is executable'
The path "$SCRIPT" should be exist
The path "$SCRIPT" should be executable
End

It 'uses set -euo pipefail'
When run bash -c "head -10 '$SCRIPT'"
The output should include 'set -euo pipefail'
The status should be success
End

It 'calls moshi-hook install'
When run bash -c "grep 'moshi-hook install' '$SCRIPT'"
The output should include 'moshi-hook install'
The status should be success
End

It 'does not render live orchestration hooks into tracked generated files'
When run bash -c "! grep -qE 'install_orchestration_hooks|orchestration hooks render' '$SCRIPT'"
The status should be success
End

It 'copies TypeScript plugin files'
When run cat "$SCRIPT"
The output should include 'omp'
The output should include 'pi'
The output should include 'opencode'
The output should include 'generated/hooks/moshi'
The status should be success
End

It 'runs nix fmt for formatting'
When run bash -c "grep 'nix fmt' '$SCRIPT'"
The output should include 'nix fmt'
The status should be success
End

It 'normalizes dcg hooks through the fail-closed wrapper without installing'
TEMP_DIR="$(mktemp -d)"
HOOKS_JSON="$TEMP_DIR/hooks.json"
cat >"$HOOKS_JSON" <<'JSON'
{
  "hooks": [
    { "command": "dcg" },
    { "command": "/nix/store/example-dcg/bin/dcg" },
    { "command": "command -v dcg >/dev/null 2>&1 && dcg" },
    { "command": "command -v dcg \u003e/dev/null 2\u003e\u00261 \u0026\u0026 dcg" },
    { "command": "unrelated-hook" }
  ]
}
JSON
When run bash -c 'bash "$1" --normalize-only "$2" && jq -r ".hooks[].command" "$2"' _ "$SCRIPT" "$HOOKS_JSON"
The status should be success
The output should eq '$HOME/dotfiles/config/shared/hooks/dcg-guard.sh
$HOME/dotfiles/config/shared/hooks/dcg-guard.sh
$HOME/dotfiles/config/shared/hooks/dcg-guard.sh
$HOME/dotfiles/config/shared/hooks/dcg-guard.sh
unrelated-hook'
rm -rf "$TEMP_DIR"
End
End

Describe 'error handling'
setup() {
  TEMP_DIR=$(mktemp -d)
  TEMP_SCRIPT="$TEMP_DIR/update-moshi-hooks-fail.sh"
  cat >"$TEMP_SCRIPT" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
echo "Installing latest moshi-hook configs..."
false  # Simulate moshi-hook not found
EOF
  chmod +x "$TEMP_SCRIPT"
}

cleanup() {
  rm -rf "$TEMP_DIR"
}

Before 'setup'
After 'cleanup'

It 'exits with error when moshi-hook is not available'
When run bash "$TEMP_SCRIPT"
The output should include 'Installing'
The status should be failure
End
End

End
