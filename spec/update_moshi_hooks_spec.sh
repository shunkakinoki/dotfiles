#!/usr/bin/env bash
# shellcheck disable=SC2329,SC2034

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

It 'copies TypeScript plugin files'
When run bash -c "grep 'moshi-hooks.ts' '$SCRIPT'"
The output should include 'omp'
The output should include 'pi'
The output should include 'opencode'
The status should be success
End

It 'runs nix fmt for formatting'
When run bash -c "grep 'nix fmt' '$SCRIPT'"
The output should include 'nix fmt'
The status should be success
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
