#!/usr/bin/env bash
# Update and build all local binaries listed in .local-binaries.txt
# Usage: ./scripts/update-local-binaries.sh [filter]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CONFIG_FILE="$REPO_ROOT/.local-binaries.txt"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Track results
declare -a SUCCESSES=()
declare -a FAILURES=()

log_info() {
  echo -e "${GREEN}$1${NC}"
}

log_warn() {
  echo -e "${YELLOW}$1${NC}"
}

log_error() {
  echo -e "${RED}$1${NC}"
}

log_step() {
  echo -e "${BLUE}$1${NC}"
}

get_ghq_root() {
  if command -v ghq >/dev/null 2>&1; then
    ghq root
  else
    echo "$HOME/ghq"
  fi
}

get_ghq_repo() {
  local repo_dir="$1"
  local ghq_root
  ghq_root="$(get_ghq_root)"

  case "$repo_dir" in
  "$ghq_root"/*)
    echo "${repo_dir#"$ghq_root/"}"
    return 0
    ;;
  esac

  return 1
}

# Extract repo directory from binary path
# e.g., ~/ghq/github.com/owner/repo/target/release/bin -> ~/ghq/github.com/owner/repo
get_repo_dir() {
  local binary_path="$1"
  # Expand ~ to $HOME
  binary_path="${binary_path/#\~/$HOME}"

  # Find the repo root by looking for .git directory
  local dir
  dir="$(dirname "$binary_path")"

  while [ "$dir" != "/" ] && [ "$dir" != "$HOME" ]; do
    if [ -d "$dir/.git" ]; then
      echo "$dir"
      return 0
    fi
    dir="$(dirname "$dir")"
  done

  # Fallback: assume 4 levels deep from ghq root (github.com/owner/repo)
  echo "$binary_path" | sed -E 's|(~/ghq/[^/]+/[^/]+/[^/]+)/.*|\1|' | sed "s|~|$HOME|"
}

# Get repo name for display
get_repo_name() {
  local repo_dir="$1"
  basename "$repo_dir"
}

# Detect and run build command
build_repo() {
  local repo_dir="$1"
  local repo_name
  repo_name="$(get_repo_name "$repo_dir")"

  log_step "  Building $repo_name..."

  if [ -f "$repo_dir/Makefile" ]; then
    if make -C "$repo_dir" build 2>&1; then
      return 0
    else
      return 1
    fi
  elif [ -f "$repo_dir/Cargo.toml" ]; then
    if (cd "$repo_dir" && cargo build --release 2>&1); then
      return 0
    else
      return 1
    fi
  else
    log_warn "  No Makefile or Cargo.toml found, skipping build"
    return 0
  fi
}

# Update a single repo
update_repo() {
  local binary_path="$1"
  local repo_dir
  repo_dir="$(get_repo_dir "$binary_path")"
  local repo_name
  repo_name="$(get_repo_name "$repo_dir")"

  echo ""
  log_info "📦 Updating $repo_name"
  echo "  Path: $repo_dir"

  if [ ! -d "$repo_dir" ]; then
    local ghq_repo
    ghq_repo="$(get_ghq_repo "$repo_dir" || true)"

    if [ -n "$ghq_repo" ] && command -v ghq >/dev/null 2>&1; then
      log_step "  Repo missing; cloning with ghq..."
      if ! ghq get "$ghq_repo" 2>&1; then
        log_error "  ghq clone failed for $ghq_repo"
        FAILURES+=("$repo_name (ghq clone failed)")
        return 1
      fi
    else
      log_error "  Directory not found: $repo_dir"
      FAILURES+=("$repo_name (not found)")
      return 1
    fi
  fi

  # Git pull
  log_step "  Pulling latest changes..."
  if ! (cd "$repo_dir" && git pull 2>&1); then
    log_error "  Git pull failed"
    FAILURES+=("$repo_name (git pull failed)")
    return 1
  fi

  # Build
  if build_repo "$repo_dir"; then
    log_info "  ✅ $repo_name updated successfully"
    SUCCESSES+=("$repo_name")
  else
    log_error "  ❌ Build failed for $repo_name"
    FAILURES+=("$repo_name (build failed)")
    return 1
  fi
}

# Print summary
print_summary() {
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  log_info "Summary"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

  if [ ${#SUCCESSES[@]} -gt 0 ]; then
    echo -e "${GREEN}✅ Successful (${#SUCCESSES[@]}):${NC}"
    for name in "${SUCCESSES[@]}"; do
      echo "   - $name"
    done
  fi

  if [ ${#FAILURES[@]} -gt 0 ]; then
    echo -e "${RED}❌ Failed (${#FAILURES[@]}):${NC}"
    for name in "${FAILURES[@]}"; do
      echo "   - $name"
    done
  fi
}

usage() {
  echo "Usage: $0 [filter]"
  echo ""
  echo "Update and build local binaries from .local-binaries.txt"
  echo ""
  echo "Arguments:"
  echo "  filter  Optional: Only update repos matching this pattern"
  echo ""
  echo "Examples:"
  echo "  $0              # Update all"
  echo "  $0 beads        # Update repos containing 'beads'"
}

main() {
  local filter="${1:-}"

  if [ "$filter" = "-h" ] || [ "$filter" = "--help" ]; then
    usage
    exit 0
  fi

  if [ ! -f "$CONFIG_FILE" ]; then
    log_error "Config file not found: $CONFIG_FILE"
    exit 1
  fi

  log_info "🔄 Updating local binaries"
  [ -n "$filter" ] && echo "  Filter: $filter"

  # Track unique repos to avoid duplicate builds
  declare -A seen_repos

  while IFS= read -r line || [ -n "$line" ]; do
    # Skip comments and empty lines
    [[ $line =~ ^[[:space:]]*# ]] && continue
    [[ -z ${line// /} ]] && continue

    # Apply filter if provided
    if [ -n "$filter" ] && [[ ! $line =~ $filter ]]; then
      continue
    fi

    # Get repo directory and check if already processed
    local repo_dir
    repo_dir="$(get_repo_dir "$line")"

    if [ -n "${seen_repos[$repo_dir]:-}" ]; then
      continue
    fi
    seen_repos[$repo_dir]=1

    # Update repo (continue on failure)
    update_repo "$line" || true

  done <"$CONFIG_FILE"

  print_summary

  # Exit with error if any failures
  if [ ${#FAILURES[@]} -gt 0 ]; then
    exit 1
  fi
}

main "$@"
