#!/usr/bin/env bash
# shellcheck disable=SC2329

Describe 'scripts/check-nix-inline-scripts.sh'
SCRIPT="$PWD/scripts/check-nix-inline-scripts.sh"

setup() {
  TEMP_DIR=$(mktemp -d)
  mkdir -p "$TEMP_DIR/scripts"
  cp -f "$SCRIPT" "$TEMP_DIR/scripts/check-nix-inline-scripts.sh"
  chmod +x "$TEMP_DIR/scripts/check-nix-inline-scripts.sh"
}

cleanup() {
  rm -rf "$TEMP_DIR"
}

Before 'setup'
After 'cleanup'

Describe 'script properties'
It 'uses bash shebang'
When run bash -c "head -1 '$SCRIPT'"
The output should include '#!/usr/bin/env bash'
End

It 'uses strict mode'
When run bash -c "grep 'set -euo pipefail' '$SCRIPT'"
The output should include 'set -euo pipefail'
End
End

Describe 'detection pattern'
It 'searches for writeScript patterns'
When run bash -c "grep 'write.*Script' '$SCRIPT'"
The output should include 'write'
End

It 'excludes .git directory'
When run bash -c "grep 'exclude-dir' '$SCRIPT'"
The output should include '.git'
End

It 'excludes .worktrees directory'
When run bash -c "grep 'exclude-dir' '$SCRIPT'"
The output should include '.worktrees'
End
End

Describe 'runtime behavior'
It 'accepts delegated bash activation blocks'
  cat >"$TEMP_DIR/good.nix" <<'EOF'
{ pkgs, config, ... }:
{
  home.activation.good = config.lib.dag.entryAfter [ "writeBoundary" ] ''
    export PATH="/tmp:$PATH"
    $DRY_RUN_CMD ${pkgs.bash}/bin/bash "${./activate.sh}" \
      "${config.home.homeDirectory}"
  '';
}
EOF
When run bash "$TEMP_DIR/scripts/check-nix-inline-scripts.sh"
The status should be success
The stdout should include 'No inline shell or Python scripts in Nix files'
End

It 'rejects inline activation commands'
  cat >"$TEMP_DIR/bad-inline.nix" <<'EOF'
{ pkgs, config, ... }:
{
  home.activation.bad = config.lib.dag.entryAfter [ "writeBoundary" ] ''
    ${pkgs.coreutils}/bin/mkdir -p "$HOME/.cache/example"
  '';
}
EOF
When run bash "$TEMP_DIR/scripts/check-nix-inline-scripts.sh"
The status should eq 1
The stderr should include 'inline shell in home.activation block'
End

It 'rejects extra commands appended to bash delegation'
  cat >"$TEMP_DIR/bad-chain.nix" <<'EOF'
{ pkgs, config, ... }:
{
  home.activation.bad = config.lib.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD ${pkgs.bash}/bin/bash "${./activate.sh}" && touch "$HOME/.pwned"
  '';
}
EOF
When run bash "$TEMP_DIR/scripts/check-nix-inline-scripts.sh"
The status should eq 1
The stderr should include 'inline shell in home.activation block'
End
End

End
