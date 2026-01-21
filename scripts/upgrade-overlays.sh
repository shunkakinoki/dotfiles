#!/usr/bin/env bash
# Extensible overlay upgrade script
# Usage: ./scripts/upgrade-overlays.sh <overlay|all>

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
OVERLAY_FILE="$REPO_ROOT/overlays/default.nix"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# --- Common utilities ---

log_info() {
  echo -e "${GREEN}$1${NC}"
}

log_warn() {
  echo -e "${YELLOW}$1${NC}"
}

log_error() {
  echo -e "${RED}$1${NC}"
}

check_dependencies() {
  local missing=()
  for cmd in gh nix-prefetch-url nix jq; do
    if ! command -v "$cmd" &>/dev/null; then
      missing+=("$cmd")
    fi
  done
  if [ ${#missing[@]} -ne 0 ]; then
    log_error "Missing required dependencies: ${missing[*]}"
    exit 1
  fi
}

fetch_latest_release() {
  local owner="$1" repo="$2"
  gh api "repos/$owner/$repo/releases/latest" --jq '.tag_name'
}

get_tag_commit() {
  local owner="$1" repo="$2" tag="$3"
  # First try to get the commit from the tag ref
  local ref_type ref_sha
  ref_type=$(gh api "repos/$owner/$repo/git/refs/tags/$tag" --jq '.object.type' 2>/dev/null || echo "")
  ref_sha=$(gh api "repos/$owner/$repo/git/refs/tags/$tag" --jq '.object.sha' 2>/dev/null || echo "")

  if [ "$ref_type" = "commit" ]; then
    echo "$ref_sha"
  elif [ "$ref_type" = "tag" ]; then
    # Annotated tag - need to dereference
    gh api "repos/$owner/$repo/git/tags/$ref_sha" --jq '.object.sha'
  else
    log_error "Could not determine commit for tag $tag"
    exit 1
  fi
}

compute_source_hash() {
  local url="$1"
  nix-prefetch-url --unpack "$url" 2>/dev/null
}

convert_to_sri() {
  local hash="$1"
  nix hash convert --hash-algo sha256 --to sri "$hash"
}

# Platform-agnostic sed in-place
sed_inplace() {
  if [[ $OSTYPE == "darwin"* ]]; then
    sed -i '' "$@"
  else
    sed -i "$@"
  fi
}

compute_pnpm_deps_hash() {
  local fake_hash="sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
  local current_hash

  # Get current pnpmDepsHash
  current_hash=$(grep 'pnpmDepsHash = "' "$OVERLAY_FILE" | head -1 | sed 's/.*pnpmDepsHash = "\([^"]*\)".*/\1/')

  echo "  Computing pnpmDepsHash (this requires a build attempt)..."

  # Temporarily set fake hash
  sed_inplace "s|pnpmDepsHash = \"[^\"]*\";|pnpmDepsHash = \"$fake_hash\";|" "$OVERLAY_FILE"

  # Run nix build and capture the correct hash from error output
  local build_output correct_hash
  build_output=$(nix build ".#darwinConfigurations.aarch64-darwin.system" --no-link 2>&1 || true)

  # Extract the correct hash from "got: sha256-..." line
  correct_hash=$(echo "$build_output" | grep -o 'got:[[:space:]]*sha256-[A-Za-z0-9+/=]*' | head -1 | sed 's/got:[[:space:]]*//')

  if [ -n "$correct_hash" ]; then
    echo "  pnpmDepsHash: $correct_hash"
    sed_inplace "s|pnpmDepsHash = \"[^\"]*\";|pnpmDepsHash = \"$correct_hash\";|" "$OVERLAY_FILE"
    return 0
  else
    # Restore original hash if we couldn't get a new one
    log_warn "  Could not determine pnpmDepsHash, restoring original"
    sed_inplace "s|pnpmDepsHash = \"[^\"]*\";|pnpmDepsHash = \"$current_hash\";|" "$OVERLAY_FILE"
    return 1
  fi
}

# --- Clawdbot upgrade ---

upgrade_clawdbot() {
  log_info "📦 Fetching latest clawdbot release..."

  local tag version rev current_version
  local tarball_url source_hash source_sri
  local app_url app_hash app_sri

  # Get current version (macOS-compatible)
  current_version=$(grep 'clawdbotVersion = "' "$OVERLAY_FILE" | head -1 | sed 's/.*clawdbotVersion = "\([^"]*\)".*/\1/' || echo "unknown")
  echo "  Current version: $current_version"

  # Fetch latest release
  tag=$(fetch_latest_release "clawdbot" "clawdbot")
  version="${tag#v}" # Remove 'v' prefix

  echo "  Latest version: $version"

  if [ "$current_version" = "$version" ]; then
    log_info "✅ Already on latest version ($version)"
    return 0
  fi

  # Get commit SHA for the tag
  echo "  Fetching commit SHA for tag $tag..."
  rev=$(get_tag_commit "clawdbot" "clawdbot" "$tag")
  echo "  Commit: $rev"

  # Compute source hash
  tarball_url="https://github.com/clawdbot/clawdbot/archive/$rev.tar.gz"
  echo "  Computing source hash (this may take a moment)..."
  source_hash=$(compute_source_hash "$tarball_url")
  source_sri=$(convert_to_sri "$source_hash")
  echo "  Source hash: $source_sri"

  # Compute app bundle hash (macOS zip)
  app_url="https://github.com/clawdbot/clawdbot/releases/download/$tag/Clawdbot-$version.zip"
  echo "  Computing app bundle hash..."
  app_hash=$(nix-prefetch-url --unpack "$app_url" 2>/dev/null)
  app_sri=$(convert_to_sri "$app_hash")
  echo "  App hash: $app_sri"

  # Update overlay file
  echo "  Updating overlays/default.nix..."

  # Update clawdbotSourceOverride
  sed_inplace "s|rev = \"[^\"]*\";|rev = \"$rev\";|" "$OVERLAY_FILE"
  sed_inplace "s|hash = \"sha256-[^\"]*\";|hash = \"$source_sri\";|" "$OVERLAY_FILE"

  # Update clawdbotAppOverride
  sed_inplace "s|version = \"[0-9][^\"]*\";|version = \"$version\";|" "$OVERLAY_FILE"
  sed_inplace "s|url = \"https://github.com/clawdbot/clawdbot/releases/download/[^\"]*\";|url = \"$app_url\";|" "$OVERLAY_FILE"

  # Update app hash (second hash in the file, after url)
  # Use awk to update only the hash in clawdbotAppOverride block
  awk -v new_hash="$app_sri" '
        /clawdbotAppOverride = \{/ { in_app_override = 1 }
        in_app_override && /hash = "sha256-/ {
            sub(/hash = "sha256-[^"]*"/, "hash = \"" new_hash "\"")
            in_app_override = 0
        }
        { print }
    ' "$OVERLAY_FILE" >"$OVERLAY_FILE.tmp" && mv "$OVERLAY_FILE.tmp" "$OVERLAY_FILE"

  # Update clawdbotVersion
  sed_inplace "s|clawdbotVersion = \"[^\"]*\";|clawdbotVersion = \"$version\";|" "$OVERLAY_FILE"

  # Update comment
  sed_inplace "s|# Override clawdbot source to v[^ ]*|# Override clawdbot source to v$version|" "$OVERLAY_FILE"
  sed_inplace "s|# Override clawdbot-app to v[^ ]* |# Override clawdbot-app to v$version |" "$OVERLAY_FILE"

  # Update pnpmDepsHash automatically
  if compute_pnpm_deps_hash; then
    log_info "✅ clawdbot upgraded from $current_version to $version"
  else
    log_info "✅ clawdbot upgraded from $current_version to $version"
    log_warn "⚠️  pnpmDepsHash may need manual verification"
  fi

  echo ""
  echo "📝 Review changes with 'git diff overlays/default.nix'"
}

# --- Main ---

update_pnpm_hash() {
  log_info "📦 Updating pnpmDepsHash..."
  if compute_pnpm_deps_hash; then
    log_info "✅ pnpmDepsHash updated successfully"
  else
    log_error "❌ Failed to update pnpmDepsHash"
    exit 1
  fi
  echo ""
  echo "📝 Review changes with 'git diff overlays/default.nix'"
}

usage() {
  echo "Usage: $0 <overlay|all|pnpm-hash>"
  echo ""
  echo "Available commands:"
  echo "  clawdbot   - Upgrade clawdbot overlay to latest release"
  echo "  pnpm-hash  - Update only pnpmDepsHash (after flake.lock changes)"
  echo "  all        - Upgrade all overlays"
  echo ""
  echo "Examples:"
  echo "  $0 clawdbot"
  echo "  $0 pnpm-hash"
  echo "  $0 all"
}

main() {
  local target="${1:-}"

  if [ -z "$target" ]; then
    usage
    exit 1
  fi

  check_dependencies

  case "$target" in
  clawdbot)
    upgrade_clawdbot
    ;;
  pnpm-hash)
    update_pnpm_hash
    ;;
  all)
    upgrade_clawdbot
    # Add more overlay upgrades here as needed:
    # upgrade_other_overlay
    ;;
  -h | --help)
    usage
    ;;
  *)
    log_error "Unknown command: $target"
    echo ""
    usage
    exit 1
    ;;
  esac
}

main "$@"
