#!/usr/bin/env bash
# Update and build all local binaries listed in .local-binaries.txt
# Usage: ./scripts/update-local-binaries.sh [filter]

set -euo pipefail

# Ensure the linker can find clang_rt on macOS (Xcode clang version may differ
# from the version some Rust crates hard-code in their build scripts).
if [ "$(uname)" = "Darwin" ]; then
  CLANG_LIB="$(echo /Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/clang/*/lib/darwin)"
  if [ -d "$CLANG_LIB" ]; then
    export LIBRARY_PATH="${CLANG_LIB}${LIBRARY_PATH:+:$LIBRARY_PATH}"
  fi
fi

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
  # Note: binary_path is already expanded, so match against the full path
  echo "$binary_path" | sed -E 's|(.*/ghq/[^/]+/[^/]+/[^/]+)/.*|\1|'
}

# Get repo name for display
get_repo_name() {
  local repo_dir="$1"
  basename "$repo_dir"
}

# Find closest ancestor directory (from binary up to repo root) that has a build file
find_build_dir() {
  local repo_dir="$1"
  local binary_path="$2"
  # Expand ~
  binary_path="${binary_path/#\~/$HOME}"

  local dir
  dir="$(dirname "$binary_path")"

  # Walk up from binary dir to repo root (inclusive)
  while true; do
    if [ -f "$dir/Makefile" ] || [ -f "$dir/Cargo.toml" ] || [ -f "$dir/go.mod" ] || [ -f "$dir/mix.exs" ]; then
      echo "$dir"
      return 0
    fi
    [ "$dir" = "$repo_dir" ] && break
    dir="$(dirname "$dir")"
  done

  # Fallback to repo root
  echo "$repo_dir"
}

# Detect and run build command
build_repo() {
  local repo_dir="$1"
  local binary_path="${2:-}"
  local repo_name
  repo_name="$(get_repo_name "$repo_dir")"

  log_step "  Building $repo_name..."

  # Use subdirectory build dir if binary path provided
  local build_dir="$repo_dir"
  if [ -n "$binary_path" ]; then
    build_dir="$(find_build_dir "$repo_dir" "$binary_path")"
  fi

  # Install tools via mise if mise.toml is present
  if [ -f "$build_dir/mise.toml" ] && command -v mise >/dev/null 2>&1; then
    log_step "  Installing tools via mise..."
    (cd "$build_dir" && mise trust 2>&1) || true
    (cd "$build_dir" && mise install 2>&1) || true
  fi

  # Initialize git submodules if .gitmodules exists
  if [ -f "$repo_dir/.gitmodules" ]; then
    log_step "  Initializing submodules..."
    (cd "$repo_dir" && git submodule update --init --recursive 2>&1) || true
  fi

  if [ -f "$build_dir/Makefile" ]; then
    # Use mise exec if mise.toml present to ensure correct tool versions
    local make_cmd="make"
    if [ -f "$build_dir/mise.toml" ] && command -v mise >/dev/null 2>&1; then
      make_cmd="mise exec -- make"
    fi
    # Run deps target first if the Makefile defines it
    if (cd "$build_dir" && $make_cmd -n deps >/dev/null 2>&1); then
      (cd "$build_dir" && $make_cmd deps 2>&1) || true
    fi
    # If Makefile has no build target, fall through to other build systems
    if (cd "$build_dir" && $make_cmd -n build >/dev/null 2>&1); then
      if (cd "$build_dir" && $make_cmd build 2>&1); then
        return 0
      else
        return 1
      fi
    else
      log_warn "  Makefile has no build target, trying other build systems..."
    fi
  fi

  if [ -f "$build_dir/Cargo.toml" ]; then
    if (cd "$build_dir" && cargo +nightly build --release 2>&1); then
      return 0
    else
      return 1
    fi
  elif [ -f "$build_dir/go.mod" ]; then
    # Go project: build ./cmd/{repo_name} if it exists, otherwise build root
    # ICU/CGo env vars are provided by shell init (fish/bash/zsh via nix)
    if [ -d "$build_dir/cmd/$repo_name" ]; then
      if (cd "$build_dir" && go build "./cmd/$repo_name" 2>&1); then
        return 0
      else
        return 1
      fi
    else
      if (cd "$build_dir" && go build 2>&1); then
        return 0
      else
        return 1
      fi
    fi
  else
    log_warn "  No Makefile, Cargo.toml, or go.mod found, skipping build"
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

  # Remove stale lock files left by crashed git processes
  if [ -f "$repo_dir/.git/index.lock" ]; then
    log_warn "  Removing stale .git/index.lock..."
    rm -f "$repo_dir/.git/index.lock"
  fi

  # If in detached HEAD state, switch to default branch
  if (cd "$repo_dir" && ! git symbolic-ref -q HEAD >/dev/null 2>&1); then
    log_warn "  Detached HEAD; switching to default branch..."
    local default_branch
    default_branch="$(cd "$repo_dir" && git remote show origin 2>/dev/null | sed -n 's/.*HEAD branch: //p')" || true
    default_branch="${default_branch:-main}"
    if ! (cd "$repo_dir" && git checkout -f "$default_branch" 2>&1); then
      log_error "  Failed to checkout $default_branch"
      FAILURES+=("$repo_name (checkout failed)")
      return 1
    fi
  fi

  # Git pull
  log_step "  Pulling latest changes..."
  if (cd "$repo_dir" && [ -n "$(git status --porcelain)" ]); then
    log_warn "  Working tree dirty; resetting to remote (destructive)..."
    if ! (
      cd "$repo_dir" &&
        git fetch --prune 2>&1 &&
        upstream_ref="$(git rev-parse --abbrev-ref --symbolic-full-name "@{u}" 2>/dev/null || true)" &&
        if [ -n "$upstream_ref" ]; then
          git reset --hard "$upstream_ref" 2>&1
        else
          git reset --hard HEAD 2>&1
        fi &&
        git clean -fd 2>&1
    ); then
      log_error "  Reset to remote failed"
      FAILURES+=("$repo_name (reset failed)")
      return 1
    fi

    if ! (cd "$repo_dir" && git pull 2>&1); then
      log_error "  Git pull failed"
      FAILURES+=("$repo_name (git pull failed)")
      return 1
    fi
  else
    if ! (cd "$repo_dir" && git pull --ff-only 2>&1); then
      log_warn "  Fast-forward failed; rebasing onto remote..."
      if ! (cd "$repo_dir" && git pull --rebase 2>&1); then
        log_error "  Git pull failed"
        FAILURES+=("$repo_name (git pull failed)")
        return 1
      fi
    fi
  fi

  # Build
  if build_repo "$repo_dir" "$binary_path"; then
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

    # Strip optional alias suffix (path:alias)
    case "$line" in
    *:*) line="${line%:*}" ;;
    esac

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
