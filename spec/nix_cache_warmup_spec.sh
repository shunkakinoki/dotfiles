#!/usr/bin/env bash
# shellcheck disable=SC2329,SC2034,SC2016

Describe 'scripts/nix-cache-warmup.sh'
SCRIPT="$PWD/scripts/nix-cache-warmup.sh"

Describe 'script properties'
It 'uses sh shebang'
When run bash -c "head -1 '$SCRIPT'"
The output should include '#!/bin/sh'
End

It 'uses strict mode'
When run bash -c "head -5 '$SCRIPT'"
The output should include 'set -e'
End
End

Describe 'github token handling'
It 'checks GITHUB_TOKEN env var'
When run bash -c "grep 'GITHUB_TOKEN' '$SCRIPT'"
The output should include 'GITHUB_TOKEN'
End

It 'checks GITHUB_TOKEN_FILE env var'
When run bash -c "grep 'GITHUB_TOKEN_FILE' '$SCRIPT'"
The output should include 'GITHUB_TOKEN_FILE'
End

It 'sets access-tokens in NIX_CONFIG'
When run bash -c "grep 'access-tokens' '$SCRIPT'"
The output should include 'access-tokens'
End

It 'unsets token variable after use'
When run bash -c "grep 'unset nix_github_token' '$SCRIPT'"
The output should include 'unset nix_github_token'
End
End

Describe 'nix availability check'
It 'checks if nix command exists'
When run bash -c "grep 'command -v nix' '$SCRIPT'"
The output should include 'command -v nix'
End

It 'skips gracefully when nix is unavailable'
When run bash -c "grep 'skipping cache warmup' '$SCRIPT'"
The output should include 'skipping cache warmup'
End
End

Describe 'flake metadata'
It 'runs nix flake metadata'
When run bash -c "grep 'nix flake metadata' '$SCRIPT'"
The output should include 'nix flake metadata'
End

It 'uses --no-write-lock-file flag'
When run bash -c "grep 'no-write-lock-file' '$SCRIPT'"
The output should include '--no-write-lock-file'
End
End

Describe 'repo directory argument'
It 'sets repo_dir'
When run bash -c "grep 'repo_dir=' '$SCRIPT'"
The output should include 'repo_dir='
End
End

Describe 'runtime behavior'
setup_runtime() {
  TEMP_DIR=$(mktemp -d)
  cp -f "$SCRIPT" "$TEMP_DIR/nix-cache-warmup.sh"
  chmod +x "$TEMP_DIR/nix-cache-warmup.sh"
  mkdir -p "$TEMP_DIR/bin"
}

cleanup_runtime() {
  rm -rf "$TEMP_DIR"
}

Before 'setup_runtime'
After 'cleanup_runtime'

It 'exits successfully when nix is unavailable'
When run env PATH="$TEMP_DIR/bin" /bin/sh "$TEMP_DIR/nix-cache-warmup.sh" "$TEMP_DIR"
The status should be success
The output should include 'Nix unavailable; skipping cache warmup'
End

It 'invokes nix flake metadata with tokenized NIX_CONFIG'
cat >"$TEMP_DIR/bin/nix" <<'EOF'
#!/bin/sh
echo "ARGS:$*" >>"$TMPDIR/nix.log"
echo "NIX_CONFIG:$NIX_CONFIG" >>"$TMPDIR/nix.log"
EOF
chmod +x "$TEMP_DIR/bin/nix"
mkdir -p "$TEMP_DIR/repo"

When run bash -c "TMPDIR='$TEMP_DIR' PATH='$TEMP_DIR/bin:$PATH' GITHUB_TOKEN='ghp_test_token' /bin/sh '$TEMP_DIR/nix-cache-warmup.sh' '$TEMP_DIR/repo' --show-trace >/dev/null; cat '$TEMP_DIR/nix.log'"
The status should be success
The output should include 'ARGS:flake metadata'
The output should include '--no-write-lock-file'
The output should include '--show-trace'
The output should include 'NIX_CONFIG:access-tokens = github.com=ghp_test_token'
End
End

End
