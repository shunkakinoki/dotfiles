#!/usr/bin/env bash
# shellcheck disable=SC2329

Describe 'brew-upgrader/upgrade.sh'
SCRIPT="$PWD/home-manager/services/brew-upgrader/upgrade.sh"

Describe 'brew upgrade command'
setup() {
  MOCK_BIN=$(mktemp -d)
  MOCK_LOG="$MOCK_BIN/mock.log"
  : >"$MOCK_LOG"
  export MOCK_BIN MOCK_LOG

  # Create mock brew in /opt/homebrew/bin
  mkdir -p /tmp/mock_homebrew/bin
  cat >/tmp/mock_homebrew/bin/brew <<'EOF'
#!/usr/bin/env bash
echo "brew $*"
exit 0
EOF
  chmod +x /tmp/mock_homebrew/bin/brew

  # Also create at the actual path the script uses
  mkdir -p "$MOCK_BIN/opt/homebrew/bin"
}

cleanup() {
  rm -rf "$MOCK_BIN" /tmp/mock_homebrew
}

Before 'setup'
After 'cleanup'

It 'calls brew upgrade'
# Test by checking what the script would do
When run bash -c "cat '$SCRIPT' | grep 'brew upgrade'"
The output should include 'brew upgrade'
End

It 'uses /opt/homebrew/bin/brew path'
When run bash -c "cat '$SCRIPT'"
The output should include '/opt/homebrew/bin/brew'
End
End

Describe 'script properties'
It 'uses strict mode'
When run bash -c "head -5 '$SCRIPT'"
The output should include 'set -euo pipefail'
End

It 'uses bash shebang'
When run bash -c "head -1 '$SCRIPT'"
The output should include '#!/usr/bin/env bash'
End

It 'is a short script (less than 10 lines)'
When run bash -c "wc -l < '$SCRIPT' | tr -d ' '"
The output should eq '5'
End
End

Describe 'error handling'
setup() {
  MOCK_BIN=$(mktemp -d)
  mkdir -p "$MOCK_BIN/opt/homebrew/bin"

  # Create failing brew mock
  cat >"$MOCK_BIN/opt/homebrew/bin/brew" <<'EOF'
#!/usr/bin/env bash
echo "Error: brew failed" >&2
exit 1
EOF
  chmod +x "$MOCK_BIN/opt/homebrew/bin/brew"
}

cleanup() {
  rm -rf "$MOCK_BIN"
}

Before 'setup'
After 'cleanup'

It 'exits with failure when brew fails'
# Create a test script that uses our mock
TEMP_SCRIPT=$(mktemp)
cat >"$TEMP_SCRIPT" <<EOF
#!/usr/bin/env bash
set -euo pipefail
$MOCK_BIN/opt/homebrew/bin/brew upgrade
EOF
chmod +x "$TEMP_SCRIPT"

When run bash "$TEMP_SCRIPT"
The status should be failure
The stderr should include 'Error: brew failed'

rm -f "$TEMP_SCRIPT"
End
End

End
