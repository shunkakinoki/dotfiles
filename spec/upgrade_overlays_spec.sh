#!/usr/bin/env bash
# shellcheck disable=SC2329,SC2034

Describe 'upgrade-overlays.sh'
SCRIPT="$PWD/scripts/upgrade-overlays.sh"

Describe 'usage and help'
It 'shows usage when called without arguments'
When run bash "$SCRIPT"
The output should include 'Usage:'
The output should include 'upgrade-overlays.sh'
The output should include 'blacksmith-testbox-cli'
The output should include 'crabbox'
The output should include 'devin'
The output should include 'moshi-hook'
The output should include 't3code'
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
  mkdir -p \
    "$TEMP_DIR/bin" \
    "$TEMP_DIR/cdn/hook/latest" \
    "$TEMP_DIR/cdn/hook/v0.2.69" \
    "$TEMP_DIR/cdn/blacksmith/v0.4.57/linux/amd64" \
    "$TEMP_DIR/cdn/blacksmith/v0.4.57/linux/arm64" \
    "$TEMP_DIR/cdn/blacksmith/v0.4.57/darwin/amd64" \
    "$TEMP_DIR/cdn/blacksmith/v0.4.57/darwin/arm64" \
    "$TEMP_DIR/cdn/crabbox/v0.55.0" \
    "$TEMP_DIR/cdn/devin/3000.10.21" \
    "$TEMP_DIR/overlays"
  cat >"$TEMP_DIR/bin/nix-prefetch-url" <<'EOF'
#!/usr/bin/env bash
case "$*" in
*darwin-arm64*) printf '%s\n' '0p85n67mklxfvvh1v6sj047wcskxsagzmg6r0wdd4kibpvgbxdap' ;;
*linux-arm64*) printf '%s\n' '1nsfky5jilcg2w87k4dlvkg1bki325j1mmf8qp93m8rjg4zq3sm1' ;;
*linux-x64*) printf '%s\n' '0jmp1xvzsnxpgakrd69fiqp2fd8rzcr57s80djlzbdgfs3jr2z60' ;;
*) exit 1 ;;
esac
EOF
  chmod +x "$TEMP_DIR/bin/nix-prefetch-url"
  export PATH="$TEMP_DIR/bin:$PATH"
  printf 'v0.2.69\n' >"$TEMP_DIR/cdn/hook/latest/version.txt"
  cat >"$TEMP_DIR/cdn/hook/v0.2.69/checksums.txt" <<'EOF'
52258126b675dad210a8f04b83d8e90b359951af37474ff985d2c3f49102d981  moshi-hook_Darwin_arm64.tar.gz
7cf24d316bafffc59d30e05d6ad6b27d4c03c9953ce901056f57f03c25e4b83b  moshi-hook_Darwin_x86_64.tar.gz
0a30e081399543551bbd0ba3320f3b28be814a585e5c591e168f8fd6d9565f07  moshi-hook_Linux_arm64.tar.gz
3903e2e5d1dba02f9e1f53df8cea6e2b3260e1581461b9a07ca65f18814b8b08  moshi-hook_Linux_x86_64.tar.gz
EOF
  for asset in \
    linux/amd64 \
    linux/arm64 \
    darwin/amd64 \
    darwin/arm64; do
    printf '%s  blacksmith\n' 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa' \
      >"$TEMP_DIR/cdn/blacksmith/v0.4.57/$asset/blacksmith.sha256"
  done
  cat >"$TEMP_DIR/cdn/crabbox/v0.55.0/checksums.txt" <<'EOF'
aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa  crabbox_0.55.0_linux_amd64.tar.gz
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb  crabbox_0.55.0_linux_arm64.tar.gz
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc  crabbox_0.55.0_darwin_arm64.tar.gz
dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd  crabbox_0.55.0_darwin_amd64.tar.gz
EOF
  cat >"$TEMP_DIR/cdn/devin/3000.10.21/manifest.json" <<'EOF'
{
  "version": "3000.10.21",
  "platforms": {
    "aarch64-apple-darwin": { "sha256": "1111111111111111111111111111111111111111111111111111111111111111" },
    "x86_64-apple-darwin": { "sha256": "2222222222222222222222222222222222222222222222222222222222222222" },
    "aarch64-unknown-linux": { "sha256": "3333333333333333333333333333333333333333333333333333333333333333" },
    "x86_64-unknown-linux": { "sha256": "4444444444444444444444444444444444444444444444444444444444444444" }
  }
}
EOF
  cat >"$TEMP_DIR/overlays/default.nix" <<'EOF'
{ inputs }:
[
  (_: prev: {
    gh = prev.gh.overrideAttrs (_: {
      version = "2.98.0";
      src = prev.fetchFromGitHub {
        rev = "0000000000000000000000000000000000000000";
        hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
      };
      vendorHash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
      buildPhase = ''
        make GH_VERSION=2.98.0 bin/gh
      '';
    });
    moshi-hook = prev.stdenv.mkDerivation rec {
      pname = "moshi-hook";
      version = "0.2.55";
      src = prev.fetchurl {
        sha256 =
          if prev.stdenv.hostPlatform.isLinux && prev.stdenv.hostPlatform.isx86_64 then
            "old-linux-x86"
          else if prev.stdenv.hostPlatform.isLinux && prev.stdenv.hostPlatform.isAarch64 then
            "old-linux-arm"
          else if prev.stdenv.isDarwin && prev.stdenv.hostPlatform.isAarch64 then
            "old-darwin-arm"
          else
            "old-darwin-x86";
      };
      sourceRoot = ".";
    };
    ascii-box-cli = prev.stdenvNoCC.mkDerivation rec {
      pname = "ascii-box-cli";
      version = "0.1.208";
      src = prev.fetchurl {
        sha256 = {
          "aarch64-darwin" = "old-darwin-arm";
          "aarch64-linux" = "old-linux-arm";
          "x86_64-linux" = "old-linux-x86";
        };
      };
      meta.mainProgram = "box";
    };
    blacksmith-testbox-cli = prev.stdenvNoCC.mkDerivation rec {
      pname = "blacksmith-testbox-cli";
      version = "0.4.57";
      src = prev.fetchurl {
        sha256 =
          if prev.stdenv.hostPlatform.isLinux && prev.stdenv.hostPlatform.isx86_64 then
            "old-linux-x86"
          else if prev.stdenv.hostPlatform.isLinux && prev.stdenv.hostPlatform.isAarch64 then
            "old-linux-arm"
          else if prev.stdenv.hostPlatform.isDarwin && prev.stdenv.hostPlatform.isAarch64 then
            "old-darwin-arm"
          else
            "old-darwin-x86";
      };
      meta.mainProgram = "blacksmith";
    };
    crabbox = prev.stdenvNoCC.mkDerivation rec {
      pname = "crabbox";
      version = "0.46.0";
      src = prev.fetchurl {
        sha256 =
          if prev.stdenv.hostPlatform.isLinux && prev.stdenv.hostPlatform.isx86_64 then
            "old-linux-x86"
          else if prev.stdenv.hostPlatform.isLinux && prev.stdenv.hostPlatform.isAarch64 then
            "old-linux-arm"
          else if prev.stdenv.hostPlatform.isDarwin && prev.stdenv.hostPlatform.isAarch64 then
            "old-darwin-arm"
          else
            "old-darwin-x86";
      };
      meta.mainProgram = "crabbox";
    };
    devin = prev.stdenvNoCC.mkDerivation rec {
      pname = "devin";
      version = "3000.10.20";
      src = prev.fetchurl {
        sha256 = {
          "aarch64-darwin" = "old-darwin-arm";
          "x86_64-darwin" = "old-darwin-x86";
          "aarch64-linux" = "old-linux-arm";
          "x86_64-linux" = "old-linux-x86";
        };
      };
      meta.mainProgram = "devin";
    };
    # t3code 0.0.33 pins one pnpm deps hash
    t3code-test = let
      pnpmDepsHashes = {
        x86_64-linux = "old-t3code-hash";
      };
      hash = pnpmDepsHashes.x86_64-linux;
    in {
      outputHash = hash;
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

resolve_gh_release() {
  cat >"$TEMP_DIR/bin/gh" <<'EOF'
#!/usr/bin/env bash
case "$*" in
*releases/latest*) printf '%s\n' 'v2.100.0' ;;
*commits/v2.100.0*) printf '%s\n' '45437bc7eeeb3359bbfddd1742f79de7652fd3e2' ;;
*) exit 1 ;;
esac
EOF
  cat >"$TEMP_DIR/bin/nix-prefetch-url" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' '0p85n67mklxfvvh1v6sj047wcskxsagzmg6r0wdd4kibpvgbxdap'
EOF
  cat >"$TEMP_DIR/bin/nix" <<'EOF'
#!/usr/bin/env bash
if [ "$1" = hash ]; then
  printf '%s\n' 'sha256-9tnSQPSqllE+Ke6LKyNbnOF1drzdEwesEuPdmWD1X5c='
else
  printf '%s\n' "$@" >"$NIX_TEST_LOG"
  printf '%s\n' 'got: sha256-ZqUs2BnasF3QBX0I2Sxh2A/CnO61Vy6gRn1hkf0n9AY=' >&2
  exit 1
fi
EOF
  chmod +x "$TEMP_DIR/bin/gh" "$TEMP_DIR/bin/nix-prefetch-url" "$TEMP_DIR/bin/nix"
  env -u GH_VERSION -u GH_REV -u GH_SOURCE_HASH -u GH_VENDOR_HASH \
    OVERLAY_FILE="$TEMP_DIR/overlays/default.nix" NIX_TEST_LOG="$TEMP_DIR/nix.log" \
    bash "$SCRIPT" gh || return
  cat "$TEMP_DIR/nix.log" "$TEMP_DIR/overlays/default.nix"
}

It 'uses resolved release values to calculate the GitHub CLI vendor hash'
When run resolve_gh_release
The output should include 'gh upgraded from 2.98.0 to 2.100.0'
The output should include 'version = "2.100.0"; src = pkgs.fetchFromGitHub'
The output should include 'rev = "45437bc7eeeb3359bbfddd1742f79de7652fd3e2"; hash = "sha256-9tnSQPSqllE+Ke6LKyNbnOF1drzdEwesEuPdmWD1X5c="'
The output should include 'vendorHash = "sha256-ZqUs2BnasF3QBX0I2Sxh2A/CnO61Vy6gRn1hkf0n9AY=";'
The status should be success
End

It 'updates every overlay hash from the all target'
When run bash -c "env OVERLAY_FILE='$TEMP_DIR/overlays/default.nix' ASCII_BOX_CLI_VERSION='0.1.208' MOSHI_HOOK_CDN='file://$TEMP_DIR/cdn' BLACKSMITH_CLI_CDN='file://$TEMP_DIR/cdn/blacksmith' BLACKSMITH_CLI_VERSION='0.4.57' CRABBOX_RELEASE_CDN='file://$TEMP_DIR/cdn/crabbox' CRABBOX_VERSION='0.55.0' DEVIN_CLI_CDN='file://$TEMP_DIR/cdn/devin' DEVIN_CLI_VERSION='3000.10.21' GH_VERSION='2.100.0' GH_REV='45437bc7eeeb3359bbfddd1742f79de7652fd3e2' GH_SOURCE_HASH='sha256-9tnSQPSqllE+Ke6LKyNbnOF1drzdEwesEuPdmWD1X5c=' GH_VENDOR_HASH='sha256-ZqUs2BnasF3QBX0I2Sxh2A/CnO61Vy6gRn1hkf0n9AY=' T3CODE_VERSION='0.0.36' T3CODE_PNPM_HASH='sha256-y/sJIluwbn65APmJ2p07FK1ScXpetCloTHtQzZMchDU=' bash '$SCRIPT' all && cat '$TEMP_DIR/overlays/default.nix'"
The output should include 'moshi-hook upgraded from 0.2.55 to 0.2.69'
The output should include 'crabbox upgraded from 0.46.0 to 0.55.0'
The output should include 'devin upgraded from 3000.10.20 to 3000.10.21'
The output should include 't3code pnpm hash refreshed for 0.0.36'
The output should include 'gh upgraded from 2.98.0 to 2.100.0'
The output should include '45437bc7eeeb3359bbfddd1742f79de7652fd3e2'
The output should include 'version = "0.55.0"'
The output should include 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
The output should include 'sha256-9tnSQPSqllE+Ke6LKyNbnOF1drzdEwesEuPdmWD1X5c='
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

It 'updates the pinned Devin CLI version and all platform checksums'
When run bash -c "env OVERLAY_FILE='$TEMP_DIR/overlays/default.nix' DEVIN_CLI_CDN='file://$TEMP_DIR/cdn/devin' DEVIN_CLI_VERSION='3000.10.21' bash '$SCRIPT' devin >/dev/null && cat '$TEMP_DIR/overlays/default.nix'"
The output should include 'version = "3000.10.21"'
The output should include '1111111111111111111111111111111111111111111111111111111111111111'
The output should include '2222222222222222222222222222222222222222222222222222222222222222'
The output should include '3333333333333333333333333333333333333333333333333333333333333333'
The output should include '4444444444444444444444444444444444444444444444444444444444444444'
The status should be success
End

It 'reads the Devin CLI version from the manifest when unpinned'
When run bash -c "env OVERLAY_FILE='$TEMP_DIR/overlays/default.nix' DEVIN_CLI_CDN='file://$TEMP_DIR/cdn/devin' bash -c \"ln -s 3000.10.21 '$TEMP_DIR/cdn/devin/current' && bash '$SCRIPT' devin\""
The output should include 'Latest version:  3000.10.21'
The output should include 'devin upgraded from 3000.10.20 to 3000.10.21'
The status should be success
End

It 'refreshes hashes when the version is unchanged'
When run bash -c "env OVERLAY_FILE='$TEMP_DIR/overlays/default.nix' ASCII_BOX_CLI_VERSION='0.1.208' bash '$SCRIPT' ascii-box-cli >/dev/null && cat '$TEMP_DIR/overlays/default.nix'"
The output should include '0jmp1xvzsnxpgakrd69fiqp2fd8rzcr57s80djlzbdgfs3jr2z60'
The status should be success
End
End

Describe 'blacksmith-testbox-cli overlay target'
setup() {
  TEMP_DIR=$(mktemp -d)
  mkdir -p \
    "$TEMP_DIR/cdn/v0.4.58/linux/amd64" \
    "$TEMP_DIR/cdn/v0.4.58/linux/arm64" \
    "$TEMP_DIR/cdn/v0.4.58/darwin/amd64" \
    "$TEMP_DIR/cdn/v0.4.58/darwin/arm64" \
    "$TEMP_DIR/overlays"
  printf '%s  dist/linux/amd64/blacksmith\n' 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa' >"$TEMP_DIR/cdn/v0.4.58/linux/amd64/blacksmith.sha256"
  printf '%s  dist/linux/arm64/blacksmith\n' 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb' >"$TEMP_DIR/cdn/v0.4.58/linux/arm64/blacksmith.sha256"
  printf '%s  dist/darwin/amd64/blacksmith\n' 'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc' >"$TEMP_DIR/cdn/v0.4.58/darwin/amd64/blacksmith.sha256"
  printf '%s  dist/darwin/arm64/blacksmith\n' 'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd' >"$TEMP_DIR/cdn/v0.4.58/darwin/arm64/blacksmith.sha256"
  cat >"$TEMP_DIR/overlays/default.nix" <<'EOF'
{ inputs }:
[
  (_: prev: {
    blacksmith-testbox-cli = prev.stdenvNoCC.mkDerivation rec {
      pname = "blacksmith-testbox-cli";
      version = "0.4.57";
      src = prev.fetchurl {
        sha256 =
          if prev.stdenv.hostPlatform.isLinux && prev.stdenv.hostPlatform.isx86_64 then
            "old-linux-x86"
          else if prev.stdenv.hostPlatform.isLinux && prev.stdenv.hostPlatform.isAarch64 then
            "old-linux-arm"
          else if prev.stdenv.isDarwin && prev.stdenv.hostPlatform.isAarch64 then
            "old-darwin-arm"
          else
            "old-darwin-x86";
      };
      meta.mainProgram = "blacksmith";
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

It 'updates the pinned version and all platform checksums'
When run bash -c "env OVERLAY_FILE='$TEMP_DIR/overlays/default.nix' BLACKSMITH_CLI_CDN='file://$TEMP_DIR/cdn' BLACKSMITH_CLI_VERSION='0.4.58' bash '$SCRIPT' blacksmith-testbox-cli >/dev/null && cat '$TEMP_DIR/overlays/default.nix'"
The output should include 'version = "0.4.58"'
The output should include 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
The output should include 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb'
The output should include 'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc'
The output should include 'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd'
The status should be success
End
End
End
