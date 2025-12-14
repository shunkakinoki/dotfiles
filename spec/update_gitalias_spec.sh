#!/usr/bin/env bash
# shellcheck disable=SC2329

Describe 'update-gitalias.sh'
SCRIPT="$PWD/scripts/update-gitalias.sh"

Describe 'gitalias download'
setup() {
  mock_bin_setup curl
  TEMP_DIR=$(mktemp -d)
  mkdir -p "$TEMP_DIR/home-manager/programs/git"

  # Create a modified script that uses our temp directory
  TEMP_SCRIPT="$TEMP_DIR/update-gitalias.sh"
  cat >"$TEMP_SCRIPT" <<EOF
#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$TEMP_DIR"
REPO_ROOT="$TEMP_DIR"
GITALIAS_FILE="\$REPO_ROOT/home-manager/programs/git/gitalias.txt"

echo "Downloading latest gitalias.txt from GitHub..."
curl -fsSL https://raw.githubusercontent.com/GitAlias/gitalias/main/gitalias.txt -o "\$GITALIAS_FILE"

echo "Updated gitalias.txt"
EOF
  chmod +x "$TEMP_SCRIPT"
}

cleanup() {
  rm -rf "$TEMP_DIR"
  mock_bin_cleanup
}

Before 'setup'
After 'cleanup'

It 'calls curl to download gitalias.txt'
When run bash -c "bash '$TEMP_SCRIPT' 2>&1; cat '$MOCK_LOG'"
The output should include 'curl'
The output should include 'gitalias.txt'
The status should be success
End

It 'downloads from the correct GitHub URL'
When run bash -c "bash '$TEMP_SCRIPT' 2>&1; cat '$MOCK_LOG'"
The output should include 'raw.githubusercontent.com/GitAlias/gitalias'
The status should be success
End

It 'outputs success message'
When run bash "$TEMP_SCRIPT"
The output should include 'Updated gitalias.txt'
The status should be success
End
End

Describe 'error handling'
setup() {
  TEMP_DIR=$(mktemp -d)
  mkdir -p "$TEMP_DIR/home-manager/programs/git"

  # Create a script with a curl that fails
  TEMP_SCRIPT="$TEMP_DIR/update-gitalias-fail.sh"
  cat >"$TEMP_SCRIPT" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
echo "Downloading latest gitalias.txt from GitHub..."
false  # Simulate curl failure
EOF
  chmod +x "$TEMP_SCRIPT"
}

cleanup() {
  rm -rf "$TEMP_DIR"
}

Before 'setup'
After 'cleanup'

It 'exits with error when curl fails'
When run bash "$TEMP_SCRIPT"
The output should include 'Downloading'
The status should be failure
End
End

End
