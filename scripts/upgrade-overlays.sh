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
  echo "  moshi-hook - Upgrade the pinned moshi-hook binaries"
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
  local asset="$1"
  awk -v asset="$asset" '$2 == asset { print $1; found = 1; exit } END { if (!found) exit 1 }' "$MOSHI_CHECKSUMS_FILE"
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

  if [[ $current_version == "$version" ]]; then
    log_info "✅ blacksmith-testbox-cli is already on latest version ($version)"
    return 0
  fi

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
  local latest_version version current_version
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

  MOSHI_CHECKSUMS_FILE="$(mktemp)"
  curl -fsSL "$MOSHI_HOOK_CDN/hook/v$version/checksums.txt" -o "$MOSHI_CHECKSUMS_FILE"

  linux_x86_64="$(checksum_for moshi-hook_Linux_x86_64.tar.gz)"
  linux_arm64="$(checksum_for moshi-hook_Linux_arm64.tar.gz)"
  darwin_arm64="$(checksum_for moshi-hook_Darwin_arm64.tar.gz)"
  darwin_x86_64="$(checksum_for moshi-hook_Darwin_x86_64.tar.gz)"
  validate_checksum moshi-hook_Linux_x86_64.tar.gz "$linux_x86_64"
  validate_checksum moshi-hook_Linux_arm64.tar.gz "$linux_arm64"
  validate_checksum moshi-hook_Darwin_arm64.tar.gz "$darwin_arm64"
  validate_checksum moshi-hook_Darwin_x86_64.tar.gz "$darwin_x86_64"

  if [[ $current_version == "$version" ]]; then
    rm -f "$MOSHI_CHECKSUMS_FILE"
    log_info "✅ moshi-hook is already on latest version ($version)"
    return 0
  fi

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
  rm -f "$MOSHI_CHECKSUMS_FILE"

  log_info "✅ moshi-hook upgraded from ${current_version:-unknown} to $version"
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
  moshi-hook)
    require_command awk
    require_command curl
    require_command sed
    require_command tr
    upgrade_moshi_hook
    ;;
  all)
    require_command awk
    require_command curl
    require_command nix-prefetch-url
    require_command sed
    require_command tr
    upgrade_ascii_box_cli
    upgrade_blacksmith_testbox_cli
    upgrade_moshi_hook
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
