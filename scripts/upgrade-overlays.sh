#!/usr/bin/env bash
# Extensible overlay upgrade script
# Usage: ./scripts/upgrade-overlays.sh <overlay|all>

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
OVERLAY_FILE="${OVERLAY_FILE:-$REPO_ROOT/overlays/default.nix}"
MOSHI_HOOK_CDN="${MOSHI_HOOK_CDN:-https://cdn.getmoshi.app}"

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
  moshi-hook | all)
    require_command awk
    require_command curl
    require_command sed
    require_command tr
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
