#!/usr/bin/env bash
# Extensible overlay upgrade script
# Usage: ./scripts/upgrade-overlays.sh <overlay|all>

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
OVERLAY_FILE="${OVERLAY_FILE:-$REPO_ROOT/overlays/default.nix}"
MOSHI_HOOK_CDN="${MOSHI_HOOK_CDN:-https://cdn.getmoshi.app}"
BLACKSMITH_CLI_CDN="${BLACKSMITH_CLI_CDN:-https://clireleases.blacksmith.sh/cli}"
ASCII_BOX_CLI_URL="${ASCII_BOX_CLI_URL:-https://ascii.dev/api/box/cli/download}"
ASCII_BOX_CLI_CHANNEL="${ASCII_BOX_CLI_CHANNEL:-ascii-prod}"
ASCII_BOX_CLI_RELEASE_URL="${ASCII_BOX_CLI_RELEASE_URL:-https://github.com/ariana-dot-dev/agent-server/releases/download}"
ASCII_BOX_CLI_RELEASE_CHANNEL="${ASCII_BOX_CLI_RELEASE_CHANNEL:-ascii-prod1}"
CRABBOX_RELEASE_API="${CRABBOX_RELEASE_API:-https://api.github.com/repos/openclaw/crabbox/releases/latest}"
CRABBOX_RELEASE_CDN="${CRABBOX_RELEASE_CDN:-https://github.com/openclaw/crabbox/releases/download}"
DEVIN_CLI_CDN="${DEVIN_CLI_CDN:-https://static.devin.ai/cli}"
GH_RELEASE_API="${GH_RELEASE_API:-repos/cli/cli/releases/latest}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
  echo -e "${GREEN}$1${NC}"
}

log_warn() {
  echo -e "${YELLOW}$1${NC}"
}

log_error() {
  echo -e "${RED}$1${NC}"
}

usage() {
  echo "Usage: $0 <overlay|all>"
  echo ""
  echo "Available overlays:"
  echo "  ascii-box-cli - Upgrade the pinned ASCII Box CLI binaries"
  echo "  blacksmith-testbox-cli - Upgrade the pinned Blacksmith Testbox CLI binaries"
  echo "  crabbox - Upgrade the pinned Crabbox binaries"
  echo "  devin - Upgrade the pinned Devin CLI binaries"
  echo "  gh - Upgrade the pinned GitHub CLI release and Go vendor hash"
  echo "  moshi-hook - Upgrade the pinned moshi-hook binaries"
  echo "  t3code - Refresh the platform-specific t3code pnpm dependency hash"
  echo "  all        - Upgrade all overlays"
  echo ""
  echo "Examples:"
  echo "  $0 moshi-hook"
  echo "  $0 all"
}

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    log_error "Missing required dependency: $1"
    exit 1
  fi
}

checksum_for() {
  local checksums_file="$1"
  local asset="$2"
  awk -v asset="$asset" '$2 == asset { print $1; found = 1; exit } END { if (!found) exit 1 }' "$checksums_file"
}

validate_checksum() {
  local asset="$1"
  local checksum="$2"
  if [[ ! $checksum =~ ^[[:xdigit:]]{64}$ ]]; then
    log_error "Invalid checksum for $asset"
    exit 1
  fi
}

checksum_from_url() {
  local url="$1"
  curl -fsSL "$url" | awk 'NR == 1 { print $1; exit }'
}

checksum_for_file() {
  local file="$1"
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$file" | awk '{ print $1 }'
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$file" | awk '{ print $1 }'
  else
    log_error "Missing SHA-256 tool: install sha256sum or shasum"
    exit 1
  fi
}

ascii_box_cli_platform() {
  local os arch

  case "$(uname -s)" in
  Darwin) os="darwin" ;;
  Linux) os="linux" ;;
  *)
    log_error "Unsupported host OS for ASCII Box CLI version probe: $(uname -s)"
    exit 1
    ;;
  esac

  case "$(uname -m)" in
  arm64 | aarch64) arch="arm64" ;;
  x86_64 | amd64) arch="x64" ;;
  *)
    log_error "Unsupported host architecture for ASCII Box CLI version probe: $(uname -m)"
    exit 1
    ;;
  esac

  printf '%s-%s' "$os" "$arch"
}

ascii_box_cli_url() {
  local platform="${1:-$(ascii_box_cli_platform)}"
  printf '%s?platform=%s&channel=%s' "$ASCII_BOX_CLI_URL" "$platform" "$ASCII_BOX_CLI_CHANNEL"
}

ascii_box_cli_release_url() {
  local platform="$1"
  local version="$2"
  printf '%s/box-cli-v%s-%s/box-%s' \
    "$ASCII_BOX_CLI_RELEASE_URL" "$version" "$ASCII_BOX_CLI_RELEASE_CHANNEL" "$platform"
}

ascii_box_cli_checksum() {
  local platform="$1"
  local version="$2"
  nix-prefetch-url --type sha256 "$(ascii_box_cli_release_url "$platform" "$version")" | sed -n '1p'
}

validate_nix_checksum() {
  local asset="$1"
  local checksum="$2"
  if [[ ! $checksum =~ ^[0-9a-z]{52}$ ]]; then
    log_error "Invalid Nix checksum for $asset"
    exit 1
  fi
}

validate_sri_checksum() {
  local asset="$1"
  local checksum="$2"
  if [[ ! $checksum =~ ^sha256-[[:alnum:]+/]{43}=$ ]]; then
    log_error "Invalid SRI checksum for $asset"
    exit 1
  fi
}

github_cli_vendor_hash() {
  local version="$1" rev="$2" source_hash="$3"
  local expression output

  if [ -n "${GH_VENDOR_HASH:-}" ]; then
    printf '%s\n' "$GH_VENDOR_HASH"
    return 0
  fi

  expression="let flake = builtins.getFlake (toString $REPO_ROOT); pkgs = flake.inputs.nixpkgs.legacyPackages.x86_64-linux; in pkgs.gh.overrideAttrs (_: { version = \"$version\"; src = pkgs.fetchFromGitHub { owner = \"cli\"; repo = \"cli\"; rev = \"$rev\"; hash = \"$source_hash\"; }; vendorHash = \"sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=\"; })"
  output="$(nix build --no-link --impure --print-build-logs --expr "$expression" 2>&1 || true)"
  printf '%s\n' "$output" | sed -n 's/.*got:[[:space:]]*\(sha256-[[:alnum:]+/]*=[=]*\).*/\1/p' | tail -1
}

upgrade_gh() {
  local version rev source_hash vendor_hash current_version
  local source_nix32

  version="${GH_VERSION:-}"
  if [ -z "$version" ]; then
    require_command gh
    version="$(gh api "$GH_RELEASE_API" --jq '.tag_name' | sed 's/^v//' | head -1)"
  fi
  if [[ ! $version =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    log_error "Invalid GitHub CLI version: ${version:-unknown}"
    exit 1
  fi

  rev="${GH_REV:-}"
  if [ -z "$rev" ]; then
    require_command gh
    rev="$(gh api "repos/cli/cli/commits/v$version" --jq '.sha')"
  fi
  if [[ ! $rev =~ ^[0-9a-f]{40}$ ]]; then
    log_error "Invalid GitHub CLI revision: ${rev:-unknown}"
    exit 1
  fi

  source_hash="${GH_SOURCE_HASH:-}"
  if [ -z "$source_hash" ]; then
    source_nix32="$(nix-prefetch-url --unpack "https://github.com/cli/cli/archive/refs/tags/v$version.tar.gz" | tail -1)"
    source_hash="$(nix hash convert --hash-algo sha256 --from nix32 --to sri "$source_nix32")"
  fi
  validate_sri_checksum "gh-$version-source" "$source_hash"

  vendor_hash="$(github_cli_vendor_hash "$version" "$rev" "$source_hash")"
  validate_sri_checksum "gh-$version-vendor" "$vendor_hash"
  current_version="$(sed -n '/gh = prev.gh.overrideAttrs/,/^[[:space:]]*});/p' "$OVERLAY_FILE" | sed -n 's/.*version = "\([^"]*\)";.*/\1/p' | head -1)"

  awk \
    -v version="$version" \
    -v rev="$rev" \
    -v source_hash="$source_hash" \
    -v vendor_hash="$vendor_hash" '
      /gh = prev\.gh\.overrideAttrs/ { in_gh = 1 }
      in_gh && /version = "[^"]*";/ {
        sub(/version = "[^"]*";/, "version = \"" version "\";")
      }
      in_gh && /rev = "[^"]*";/ {
        sub(/rev = "[^"]*";/, "rev = \"" rev "\";")
      }
      in_gh && /^[[:space:]]*hash = "[^"]*";/ && !source_updated {
        sub(/hash = "[^"]*";/, "hash = \"" source_hash "\";")
        source_updated = 1
      }
      in_gh && /vendorHash = "[^"]*";/ {
        sub(/vendorHash = "[^"]*";/, "vendorHash = \"" vendor_hash "\";")
        vendor_updated = 1
      }
      in_gh && /GH_VERSION=[^ ]+/ {
        sub(/GH_VERSION=[^ ]+/, "GH_VERSION=" version)
      }
      in_gh && /^[[:space:]]*\}\);$/ { in_gh = 0 }
      { print }
      END {
        if (source_updated != 1 || vendor_updated != 1) {
          print "expected GitHub CLI source and vendor hashes in " FILENAME > "/dev/stderr"
          exit 1
        }
      }
    ' "$OVERLAY_FILE" >"$OVERLAY_FILE.tmp"
  mv -f "$OVERLAY_FILE.tmp" "$OVERLAY_FILE"

  log_info "✅ gh upgraded from ${current_version:-unknown} to $version"
}

upgrade_ascii_box_cli() {
  local version current_version latest_dir latest_output probe_url
  local darwin_arm64 linux_arm64 linux_x86_64

  version="${ASCII_BOX_CLI_VERSION:-}"
  if [ -z "$version" ]; then
    latest_dir="$(mktemp -d)"
    probe_url="$(ascii_box_cli_url)"
    curl -fsSL "$probe_url" -o "$latest_dir/box"
    chmod +x "$latest_dir/box"
    latest_output="$("$latest_dir/box" --version)"
    rm -rf "$latest_dir"
    version="$(printf '%s\n' "$latest_output" | sed -n 's/^box \([0-9][0-9.]*\).*/\1/p')"
  fi

  if [[ ! $version =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    log_error "Invalid ASCII Box CLI version: ${version:-unknown}"
    exit 1
  fi

  current_version="$(sed -n '/ascii-box-cli = prev.stdenvNoCC.mkDerivation rec {/,/meta.mainProgram = "box"/p' "$OVERLAY_FILE" | sed -n 's/.*version = "\([^"]*\)";.*/\1/p' | head -1)"
  echo "  Current version: ${current_version:-unknown}"
  echo "  Latest version:  $version"

  darwin_arm64="$(ascii_box_cli_checksum darwin-arm64 "$version")"
  linux_arm64="$(ascii_box_cli_checksum linux-arm64 "$version")"
  linux_x86_64="$(ascii_box_cli_checksum linux-x64 "$version")"
  validate_nix_checksum ascii-box-darwin-arm64 "$darwin_arm64"
  validate_nix_checksum ascii-box-linux-arm64 "$linux_arm64"
  validate_nix_checksum ascii-box-linux-x64 "$linux_x86_64"

  awk \
    -v version="$version" \
    -v darwin_arm64="$darwin_arm64" \
    -v linux_arm64="$linux_arm64" \
    -v linux_x86_64="$linux_x86_64" '
      /ascii-box-cli = prev.stdenvNoCC.mkDerivation rec \{/ { in_ascii_box = 1 }
      in_ascii_box && /version = "[^"]*";/ {
        sub(/version = "[^"]*";/, "version = \"" version "\";")
      }
      in_ascii_box && /"aarch64-darwin" =/ {
        sub(/"[^"]*";$/, "\"" darwin_arm64 "\";")
      }
      in_ascii_box && /"aarch64-linux" =/ {
        sub(/"[^"]*";$/, "\"" linux_arm64 "\";")
      }
      in_ascii_box && /"x86_64-linux" =/ {
        sub(/"[^"]*";$/, "\"" linux_x86_64 "\";")
      }
      in_ascii_box && /meta.mainProgram = "box"/ { in_ascii_box = 0 }
      { print }
    ' "$OVERLAY_FILE" >"$OVERLAY_FILE.tmp"
  mv -f "$OVERLAY_FILE.tmp" "$OVERLAY_FILE"

  if [[ $current_version == "$version" ]]; then
    log_info "✅ ascii-box-cli hashes refreshed for $version"
  else
    log_info "✅ ascii-box-cli upgraded from ${current_version:-unknown} to $version"
  fi
}

upgrade_blacksmith_testbox_cli() {
  local version current_version latest_dir latest_output latest_checksum latest_actual
  local linux_x86_64 linux_arm64 darwin_arm64 darwin_x86_64
  local probe_os probe_arch probe_asset

  version="${BLACKSMITH_CLI_VERSION:-}"
  if [ -z "$version" ]; then
    case "$(uname -s)" in
    Darwin) probe_os="darwin" ;;
    Linux) probe_os="linux" ;;
    *)
      log_error "Unsupported host OS for Blacksmith version probe: $(uname -s)"
      exit 1
      ;;
    esac
    case "$(uname -m)" in
    arm64 | aarch64) probe_arch="arm64" ;;
    x86_64 | amd64) probe_arch="amd64" ;;
    *)
      log_error "Unsupported host architecture for Blacksmith version probe: $(uname -m)"
      exit 1
      ;;
    esac
    probe_asset="$BLACKSMITH_CLI_CDN/latest/$probe_os/$probe_arch/blacksmith"
    latest_dir="$(mktemp -d)"
    curl -fsSL "$probe_asset" -o "$latest_dir/blacksmith"
    latest_checksum="$(checksum_from_url "$probe_asset.sha256")"
    validate_checksum "blacksmith-latest-$probe_os-$probe_arch" "$latest_checksum"
    latest_actual="$(checksum_for_file "$latest_dir/blacksmith")"
    if [ "$latest_checksum" != "$latest_actual" ]; then
      rm -rf "$latest_dir"
      log_error "Checksum verification failed for the latest Blacksmith Testbox CLI"
      exit 1
    fi
    chmod +x "$latest_dir/blacksmith"
    latest_output="$("$latest_dir/blacksmith" --version)"
    rm -rf "$latest_dir"
    version="$(printf '%s\n' "$latest_output" | sed -n 's/^blacksmith version \([0-9][0-9.]*\)$/\1/p')"
  fi

  if [[ ! $version =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    log_error "Invalid Blacksmith Testbox CLI version: ${version:-unknown}"
    exit 1
  fi

  current_version="$(sed -n '/blacksmith-testbox-cli = prev.stdenvNoCC.mkDerivation rec {/,/meta.mainProgram = "blacksmith"/p' "$OVERLAY_FILE" | sed -n 's/.*version = "\([^"]*\)";.*/\1/p' | head -1)"
  echo "  Current version: ${current_version:-unknown}"
  echo "  Latest version:  $version"

  linux_x86_64="$(checksum_from_url "$BLACKSMITH_CLI_CDN/v$version/linux/amd64/blacksmith.sha256")"
  linux_arm64="$(checksum_from_url "$BLACKSMITH_CLI_CDN/v$version/linux/arm64/blacksmith.sha256")"
  darwin_arm64="$(checksum_from_url "$BLACKSMITH_CLI_CDN/v$version/darwin/arm64/blacksmith.sha256")"
  darwin_x86_64="$(checksum_from_url "$BLACKSMITH_CLI_CDN/v$version/darwin/amd64/blacksmith.sha256")"
  validate_checksum blacksmith-linux-amd64 "$linux_x86_64"
  validate_checksum blacksmith-linux-arm64 "$linux_arm64"
  validate_checksum blacksmith-darwin-arm64 "$darwin_arm64"
  validate_checksum blacksmith-darwin-amd64 "$darwin_x86_64"

  awk \
    -v version="$version" \
    -v linux_x86_64="$linux_x86_64" \
    -v linux_arm64="$linux_arm64" \
    -v darwin_arm64="$darwin_arm64" \
    -v darwin_x86_64="$darwin_x86_64" '
      /blacksmith-testbox-cli = prev.stdenvNoCC.mkDerivation rec \{/ { in_blacksmith = 1 }
      in_blacksmith && /version = "[^"]*";/ {
        sub(/version = "[^"]*";/, "version = \"" version "\";")
      }
      in_blacksmith && /isLinux && prev.stdenv.hostPlatform.isx86_64 then/ { pending_hash = linux_x86_64 }
      in_blacksmith && /isLinux && prev.stdenv.hostPlatform.isAarch64 then/ { pending_hash = linux_arm64 }
      in_blacksmith && /isDarwin && prev.stdenv.hostPlatform.isAarch64 then/ { pending_hash = darwin_arm64 }
      in_blacksmith && /^          else$/ { pending_hash = darwin_x86_64 }
      in_blacksmith && pending_hash != "" && $0 ~ /^[[:space:]]*"[^"]*";?$/ {
        sub(/"[^"]*"/, "\"" pending_hash "\"")
        pending_hash = ""
        updated_hashes++
      }
      in_blacksmith && /^    \};$/ { in_blacksmith = 0 }
      { print }
      END {
        if (updated_hashes != 4) {
          print "expected four blacksmith-testbox-cli checksums in " FILENAME > "/dev/stderr"
          exit 1
        }
      }
    ' "$OVERLAY_FILE" >"$OVERLAY_FILE.tmp"
  mv -f "$OVERLAY_FILE.tmp" "$OVERLAY_FILE"

  log_info "✅ blacksmith-testbox-cli upgraded from ${current_version:-unknown} to $version"
}

upgrade_moshi_hook() {
  local latest_version version current_version checksums_file
  local linux_x86_64 linux_arm64 darwin_arm64 darwin_x86_64

  latest_version="$(curl -fsSL "$MOSHI_HOOK_CDN/hook/latest/version.txt" | tr -d '[:space:]')"
  case "$latest_version" in
  v*) version="${latest_version#v}" ;;
  *) version="$latest_version" ;;
  esac

  if [[ ! $version =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    log_error "Invalid moshi-hook version: $latest_version"
    exit 1
  fi

  current_version="$(sed -n '/moshi-hook = prev.stdenv.mkDerivation rec {/,/sourceRoot =/p' "$OVERLAY_FILE" | sed -n 's/.*version = "\([^"]*\)";.*/\1/p' | head -1)"
  echo "  Current version: ${current_version:-unknown}"
  echo "  Latest version:  $version"

  checksums_file="$(mktemp)"
  curl -fsSL "$MOSHI_HOOK_CDN/hook/v$version/checksums.txt" -o "$checksums_file"

  linux_x86_64="$(checksum_for "$checksums_file" moshi-hook_Linux_x86_64.tar.gz)"
  linux_arm64="$(checksum_for "$checksums_file" moshi-hook_Linux_arm64.tar.gz)"
  darwin_arm64="$(checksum_for "$checksums_file" moshi-hook_Darwin_arm64.tar.gz)"
  darwin_x86_64="$(checksum_for "$checksums_file" moshi-hook_Darwin_x86_64.tar.gz)"
  validate_checksum moshi-hook_Linux_x86_64.tar.gz "$linux_x86_64"
  validate_checksum moshi-hook_Linux_arm64.tar.gz "$linux_arm64"
  validate_checksum moshi-hook_Darwin_arm64.tar.gz "$darwin_arm64"
  validate_checksum moshi-hook_Darwin_x86_64.tar.gz "$darwin_x86_64"

  awk \
    -v version="$version" \
    -v linux_x86_64="$linux_x86_64" \
    -v linux_arm64="$linux_arm64" \
    -v darwin_arm64="$darwin_arm64" \
    -v darwin_x86_64="$darwin_x86_64" '
      /moshi-hook = prev.stdenv.mkDerivation rec \{/ { in_moshi = 1 }
      in_moshi && /version = "[^"]*";/ {
        sub(/version = "[^"]*";/, "version = \"" version "\";")
      }
      in_moshi && /isLinux && prev.stdenv.hostPlatform.isx86_64 then/ { pending_hash = linux_x86_64 }
      in_moshi && /isLinux && prev.stdenv.hostPlatform.isAarch64 then/ { pending_hash = linux_arm64 }
      in_moshi && /isDarwin && prev.stdenv.hostPlatform.isAarch64 then/ { pending_hash = darwin_arm64 }
      in_moshi && /^          else$/ { pending_hash = darwin_x86_64 }
      in_moshi && pending_hash != "" && $0 ~ /^[[:space:]]*"[^"]*";?$/ {
        sub(/"[^"]*"/, "\"" pending_hash "\"")
        pending_hash = ""
        updated_hashes++
      }
      in_moshi && /^    \};$/ { in_moshi = 0 }
      { print }
      END {
        if (updated_hashes != 4) {
          print "expected four moshi-hook checksums in " FILENAME > "/dev/stderr"
          exit 1
        }
      }
    ' "$OVERLAY_FILE" >"$OVERLAY_FILE.tmp"
  mv -f "$OVERLAY_FILE.tmp" "$OVERLAY_FILE"
  rm -f "$checksums_file"

  log_info "✅ moshi-hook upgraded from ${current_version:-unknown} to $version"
}

upgrade_crabbox() {
  local version current_version checksums_file
  local linux_x86_64 linux_arm64 darwin_arm64 darwin_x86_64

  version="${CRABBOX_VERSION:-}"
  if [ -z "$version" ]; then
    require_command gh
    version="$(gh api "$CRABBOX_RELEASE_API" --jq '.tag_name' | sed 's/^v//' | head -1)"
  fi

  if [[ ! $version =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    log_error "Invalid Crabbox version: ${version:-unknown}"
    exit 1
  fi

  current_version="$(sed -n '/crabbox = prev.stdenvNoCC.mkDerivation rec {/,/meta.mainProgram = "crabbox"/p' "$OVERLAY_FILE" | sed -n 's/.*version = "\([^"]*\)";.*/\1/p' | head -1)"
  echo "  Current version: ${current_version:-unknown}"
  echo "  Latest version:  $version"

  checksums_file="$(mktemp)"
  curl -fsSL "$CRABBOX_RELEASE_CDN/v$version/checksums.txt" -o "$checksums_file"
  linux_x86_64="$(checksum_for "$checksums_file" "crabbox_${version}_linux_amd64.tar.gz")"
  linux_arm64="$(checksum_for "$checksums_file" "crabbox_${version}_linux_arm64.tar.gz")"
  darwin_arm64="$(checksum_for "$checksums_file" "crabbox_${version}_darwin_arm64.tar.gz")"
  darwin_x86_64="$(checksum_for "$checksums_file" "crabbox_${version}_darwin_amd64.tar.gz")"
  rm -f "$checksums_file"
  validate_checksum "crabbox_${version}_linux_amd64.tar.gz" "$linux_x86_64"
  validate_checksum "crabbox_${version}_linux_arm64.tar.gz" "$linux_arm64"
  validate_checksum "crabbox_${version}_darwin_arm64.tar.gz" "$darwin_arm64"
  validate_checksum "crabbox_${version}_darwin_amd64.tar.gz" "$darwin_x86_64"

  awk \
    -v version="$version" \
    -v linux_x86_64="$linux_x86_64" \
    -v linux_arm64="$linux_arm64" \
    -v darwin_arm64="$darwin_arm64" \
    -v darwin_x86_64="$darwin_x86_64" '
      /crabbox = prev.stdenvNoCC.mkDerivation rec \{/ { in_crabbox = 1 }
      in_crabbox && /version = "[^"]*";/ {
        sub(/version = "[^"]*";/, "version = \"" version "\";")
      }
      in_crabbox && /isLinux && prev.stdenv.hostPlatform.isx86_64 then/ { pending_hash = linux_x86_64 }
      in_crabbox && /isLinux && prev.stdenv.hostPlatform.isAarch64 then/ { pending_hash = linux_arm64 }
      in_crabbox && /isDarwin && prev.stdenv.hostPlatform.isAarch64 then/ { pending_hash = darwin_arm64 }
      in_crabbox && /^          else$/ { pending_hash = darwin_x86_64 }
      in_crabbox && pending_hash != "" && $0 ~ /^[[:space:]]*"[^"]*";?$/ {
        sub(/"[^"]*"/, "\"" pending_hash "\"")
        pending_hash = ""
        updated_hashes++
      }
      in_crabbox && /meta.mainProgram = "crabbox"/ { in_crabbox = 0 }
      { print }
      END {
        if (updated_hashes != 4) {
          print "expected four crabbox checksums in " FILENAME > "/dev/stderr"
          exit 1
        }
      }
    ' "$OVERLAY_FILE" >"$OVERLAY_FILE.tmp"
  mv -f "$OVERLAY_FILE.tmp" "$OVERLAY_FILE"

  log_info "✅ crabbox upgraded from ${current_version:-unknown} to $version"
}

upgrade_devin() {
  local version current_version manifest
  local darwin_arm64 darwin_x86_64 linux_arm64 linux_x86_64

  manifest="$(curl -fsSL "$DEVIN_CLI_CDN/${DEVIN_CLI_VERSION:-current}/manifest.json")"
  version="${DEVIN_CLI_VERSION:-$(printf '%s' "$manifest" | jq -r '.version')}"

  if [[ ! $version =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    log_error "Invalid Devin CLI version: ${version:-unknown}"
    exit 1
  fi

  current_version="$(sed -n '/devin = prev.stdenvNoCC.mkDerivation rec {/,/meta.mainProgram = "devin"/p' "$OVERLAY_FILE" | sed -n 's/.*version = "\([^"]*\)";.*/\1/p' | head -1)"
  echo "  Current version: ${current_version:-unknown}"
  echo "  Latest version:  $version"

  darwin_arm64="$(printf '%s' "$manifest" | jq -r '.platforms["aarch64-apple-darwin"].sha256')"
  darwin_x86_64="$(printf '%s' "$manifest" | jq -r '.platforms["x86_64-apple-darwin"].sha256')"
  linux_arm64="$(printf '%s' "$manifest" | jq -r '.platforms["aarch64-unknown-linux"].sha256')"
  linux_x86_64="$(printf '%s' "$manifest" | jq -r '.platforms["x86_64-unknown-linux"].sha256')"
  validate_checksum devin-aarch64-apple-darwin "$darwin_arm64"
  validate_checksum devin-x86_64-apple-darwin "$darwin_x86_64"
  validate_checksum devin-aarch64-unknown-linux "$linux_arm64"
  validate_checksum devin-x86_64-unknown-linux "$linux_x86_64"

  awk \
    -v version="$version" \
    -v darwin_arm64="$darwin_arm64" \
    -v darwin_x86_64="$darwin_x86_64" \
    -v linux_arm64="$linux_arm64" \
    -v linux_x86_64="$linux_x86_64" '
      /devin = prev.stdenvNoCC.mkDerivation rec \{/ { in_devin = 1 }
      in_devin && /version = "[^"]*";/ {
        sub(/version = "[^"]*";/, "version = \"" version "\";")
      }
      in_devin && /"aarch64-darwin" =/ {
        sub(/"[^"]*";$/, "\"" darwin_arm64 "\";")
        updated_hashes++
      }
      in_devin && /"x86_64-darwin" =/ {
        sub(/"[^"]*";$/, "\"" darwin_x86_64 "\";")
        updated_hashes++
      }
      in_devin && /"aarch64-linux" =/ {
        sub(/"[^"]*";$/, "\"" linux_arm64 "\";")
        updated_hashes++
      }
      in_devin && /"x86_64-linux" =/ {
        sub(/"[^"]*";$/, "\"" linux_x86_64 "\";")
        updated_hashes++
      }
      in_devin && /meta.mainProgram = "devin"/ { in_devin = 0 }
      { print }
      END {
        if (updated_hashes != 4) {
          print "expected four devin checksums in " FILENAME > "/dev/stderr"
          exit 1
        }
      }
    ' "$OVERLAY_FILE" >"$OVERLAY_FILE.tmp"
  mv -f "$OVERLAY_FILE.tmp" "$OVERLAY_FILE"

  if [[ $current_version == "$version" ]]; then
    log_info "✅ devin hashes refreshed for $version"
  else
    log_info "✅ devin upgraded from ${current_version:-unknown} to $version"
  fi
}

t3code_pnpm_hash() {
  local expression output

  if [ -n "${T3CODE_PNPM_HASH:-}" ]; then
    printf '%s\n' "$T3CODE_PNPM_HASH"
    return 0
  fi

  expression="let flake = builtins.getFlake (toString $REPO_ROOT); package = flake.inputs.llm-agents.packages.x86_64-linux.t3code; in package.pnpmDeps.overrideAttrs (_: { outputHash = \"sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=\"; })"
  output="$(nix build --no-link --impure --print-build-logs --expr "$expression" 2>&1 || true)"
  printf '%s\n' "$output" | sed -n 's/.*got:[[:space:]]*\(sha256-[[:alnum:]+/]*=[=]*\).*/\1/p' | tail -1
}

upgrade_t3code() {
  local version current_hash latest_hash

  version="${T3CODE_VERSION:-}"
  if [ -z "$version" ]; then
    version="$(nix eval --impure --raw --expr "let flake = builtins.getFlake (toString $REPO_ROOT); in flake.inputs.llm-agents.packages.x86_64-linux.t3code.version")"
  fi
  current_hash="$(sed -n '/# t3code [0-9][0-9.]* pins one pnpm deps hash/,/outputHash = hash;/p' "$OVERLAY_FILE" | sed -n 's/.*# t3code \([0-9][0-9.]*\) pins.*/\1/p' | head -1)"
  latest_hash="$(t3code_pnpm_hash)"
  validate_sri_checksum "t3code-${version}-x86_64-linux" "$latest_hash"

  awk \
    -v version="$version" \
    -v hash="$latest_hash" '
      /# t3code [0-9][0-9.]* pins one pnpm deps hash/ {
        sub(/# t3code [0-9][0-9.]*/, "# t3code " version)
      }
      /x86_64-linux = "[^"]*";/ && in_t3code {
        sub(/"[^"]*"/, "\"" hash "\"")
        updated_hashes++
      }
      /# t3code [0-9][0-9.]* pins one pnpm deps hash/ { in_t3code = 1 }
      in_t3code && /outputHash = hash;/ { in_t3code = 0 }
      { print }
      END {
        if (updated_hashes != 1) {
          print "expected one t3code platform hash in " FILENAME > "/dev/stderr"
          exit 1
        }
      }
    ' "$OVERLAY_FILE" >"$OVERLAY_FILE.tmp"
  mv -f "$OVERLAY_FILE.tmp" "$OVERLAY_FILE"

  log_info "✅ t3code pnpm hash refreshed for ${version} (was ${current_hash:-unknown})"
}

main() {
  local target="${1:-}"

  if [ -z "$target" ]; then
    usage
    exit 1
  fi

  case "$target" in
  ascii-box-cli)
    require_command awk
    require_command curl
    require_command nix-prefetch-url
    require_command sed
    upgrade_ascii_box_cli
    ;;
  blacksmith-testbox-cli)
    require_command awk
    require_command curl
    require_command sed
    upgrade_blacksmith_testbox_cli
    ;;
  crabbox)
    require_command awk
    require_command curl
    require_command sed
    upgrade_crabbox
    ;;
  devin)
    require_command awk
    require_command curl
    require_command jq
    require_command sed
    upgrade_devin
    ;;
  gh)
    require_command awk
    require_command nix
    require_command nix-prefetch-url
    require_command sed
    upgrade_gh
    ;;
  moshi-hook)
    require_command awk
    require_command curl
    require_command sed
    require_command tr
    upgrade_moshi_hook
    ;;
  t3code)
    require_command awk
    require_command nix
    require_command sed
    upgrade_t3code
    ;;
  all)
    require_command awk
    require_command curl
    require_command jq
    require_command nix-prefetch-url
    require_command nix
    require_command sed
    require_command tr
    upgrade_ascii_box_cli
    upgrade_blacksmith_testbox_cli
    upgrade_crabbox
    upgrade_devin
    upgrade_gh
    upgrade_moshi_hook
    upgrade_t3code
    ;;
  -h | --help)
    usage
    ;;
  *)
    log_error "Unknown overlay: $target"
    echo ""
    usage
    exit 1
    ;;
  esac
}

main "$@"
