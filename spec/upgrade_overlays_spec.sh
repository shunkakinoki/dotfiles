#!/usr/bin/env bash
# shellcheck disable=SC2329,SC2034

Describe 'upgrade-overlays.sh'
SCRIPT="$PWD/scripts/upgrade-overlays.sh"

Describe 'usage and help'
It 'shows usage when called without arguments'
When run bash "$SCRIPT"
The output should include 'Usage:'
The output should include 'upgrade-overlays.sh'
The output should include 'moshi-hook'
The output should include 'all'
The status should be failure
End

It 'shows usage with --help flag'
When run bash "$SCRIPT" --help
The output should include 'Usage:'
The output should include 'Available overlays:'
The status should be success
End

It 'shows usage with -h flag'
When run bash "$SCRIPT" -h
The output should include 'Usage:'
The status should be success
End
End

Describe 'unknown overlay handling'
It 'fails for unknown overlay'
When run bash "$SCRIPT" unknown-overlay
The output should include 'Unknown overlay: unknown-overlay'
The output should include 'Available overlays'
The status should be failure
End
End

Describe 'moshi-hook overlay target'
setup() {
  TEMP_DIR=$(mktemp -d)
  mkdir -p "$TEMP_DIR/cdn/hook/latest" "$TEMP_DIR/cdn/hook/v0.2.69" "$TEMP_DIR/overlays"
  printf 'v0.2.69\n' >"$TEMP_DIR/cdn/hook/latest/version.txt"
  cat >"$TEMP_DIR/cdn/hook/v0.2.69/checksums.txt" <<'EOF'
52258126b675dad210a8f04b83d8e90b359951af37474ff985d2c3f49102d981  moshi-hook_Darwin_arm64.tar.gz
7cf24d316bafffc59d30e05d6ad6b27d4c03c9953ce901056f57f03c25e4b83b  moshi-hook_Darwin_x86_64.tar.gz
0a30e081399543551bbd0ba3320f3b28be814a585e5c591e168f8fd6d9565f07  moshi-hook_Linux_arm64.tar.gz
3903e2e5d1dba02f9e1f53df8cea6e2b3260e1581461b9a07ca65f18814b8b08  moshi-hook_Linux_x86_64.tar.gz
EOF
  cat >"$TEMP_DIR/overlays/default.nix" <<'EOF'
{ inputs }:
[
  (_: prev: {
    moshi-hook = prev.stdenv.mkDerivation rec {
      pname = "moshi-hook";
      version = "0.2.55";
      src = prev.fetchurl {
        sha256 =
          if prev.stdenv.isLinux && prev.stdenv.hostPlatform.isx86_64 then
            "old-linux-x86"
          else if prev.stdenv.isLinux && prev.stdenv.hostPlatform.isAarch64 then
            "old-linux-arm"
          else if prev.stdenv.isDarwin && prev.stdenv.hostPlatform.isAarch64 then
            "old-darwin-arm"
          else
            "old-darwin-x86";
      };
      sourceRoot = ".";
    };
  })
]
EOF
}

cleanup() {
  rm -rf "$TEMP_DIR"
}

Before 'setup'
After 'cleanup'

It 'updates moshi-hook from the all target'
When run env OVERLAY_FILE="$TEMP_DIR/overlays/default.nix" MOSHI_HOOK_CDN="file://$TEMP_DIR/cdn" bash "$SCRIPT" all
The output should include 'moshi-hook upgraded from 0.2.55 to 0.2.69'
The status should be success
End

It 'updates the version and all platform checksums'
When run bash -c "env OVERLAY_FILE='$TEMP_DIR/overlays/default.nix' MOSHI_HOOK_CDN='file://$TEMP_DIR/cdn' bash '$SCRIPT' moshi-hook >/dev/null && cat '$TEMP_DIR/overlays/default.nix'"
The output should include 'version = "0.2.69"'
The output should include '3903e2e5d1dba02f9e1f53df8cea6e2b3260e1581461b9a07ca65f18814b8b08'
The output should include '0a30e081399543551bbd0ba3320f3b28be814a585e5c591e168f8fd6d9565f07'
The output should include '52258126b675dad210a8f04b83d8e90b359951af37474ff985d2c3f49102d981'
The output should include '7cf24d316bafffc59d30e05d6ad6b27d4c03c9953ce901056f57f03c25e4b83b'
The status should be success
End
End
End
