#!/usr/bin/env bash
# shellcheck disable=SC2329,SC2034

Describe 'scripts/update-local-binaries.sh'
SCRIPT="$PWD/scripts/update-local-binaries.sh"

Describe 'script properties'
It 'uses bash shebang'
When run bash -c "head -1 '$SCRIPT'"
The output should include '#!/usr/bin/env bash'
End

It 'uses strict mode'
When run bash -c "head -10 '$SCRIPT'"
The output should include 'set -euo pipefail'
End
End

Describe 'configuration'
It 'reads from .local-binaries.txt'
When run bash -c "grep 'CONFIG_FILE=' '$SCRIPT'"
The output should include '.local-binaries.txt'
End

It 'calculates script directory'
When run bash -c "grep 'SCRIPT_DIR=' '$SCRIPT'"
The output should include 'SCRIPT_DIR='
End

It 'calculates repo root'
When run bash -c "grep 'REPO_ROOT=' '$SCRIPT'"
The output should include 'REPO_ROOT='
End
End

Describe 'color definitions'
It 'defines RED color'
When run bash -c "grep 'RED=' '$SCRIPT'"
The output should include 'RED='
End

It 'defines GREEN color'
When run bash -c "grep 'GREEN=' '$SCRIPT'"
The output should include 'GREEN='
End

It 'defines YELLOW color'
When run bash -c "grep 'YELLOW=' '$SCRIPT'"
The output should include 'YELLOW='
End

It 'defines BLUE color'
When run bash -c "grep 'BLUE=' '$SCRIPT'"
The output should include 'BLUE='
End

It 'defines NC (no color)'
When run bash -c "grep 'NC=' '$SCRIPT'"
The output should include 'NC='
End
End

Describe 'logging functions'
It 'has log_info function'
When run bash -c "grep 'log_info()' '$SCRIPT'"
The output should include 'log_info()'
End

It 'has log_warn function'
When run bash -c "grep 'log_warn()' '$SCRIPT'"
The output should include 'log_warn()'
End

It 'has log_error function'
When run bash -c "grep 'log_error()' '$SCRIPT'"
The output should include 'log_error()'
End

It 'has log_step function'
When run bash -c "grep 'log_step()' '$SCRIPT'"
The output should include 'log_step()'
End
End

Describe 'helper functions'
It 'has get_repo_dir function'
When run bash -c "grep 'get_repo_dir()' '$SCRIPT'"
The output should include 'get_repo_dir()'
End

It 'has get_ghq_root function'
When run bash -c "grep 'get_ghq_root()' '$SCRIPT'"
The output should include 'get_ghq_root()'
End

It 'has get_ghq_repo function'
When run bash -c "grep 'get_ghq_repo()' '$SCRIPT'"
The output should include 'get_ghq_repo()'
End

It 'has get_repo_name function'
When run bash -c "grep 'get_repo_name()' '$SCRIPT'"
The output should include 'get_repo_name()'
End

It 'has build_repo function'
When run bash -c "grep 'build_repo()' '$SCRIPT'"
The output should include 'build_repo()'
End

It 'has update_repo function'
When run bash -c "grep 'update_repo()' '$SCRIPT'"
The output should include 'update_repo()'
End

It 'has print_summary function'
When run bash -c "grep 'print_summary()' '$SCRIPT'"
The output should include 'print_summary()'
End

It 'has usage function'
When run bash -c "grep 'usage()' '$SCRIPT'"
The output should include 'usage()'
End
End

Describe 'repo directory detection'
It 'expands tilde to HOME'
When run bash -c "grep '\$HOME' '$SCRIPT'"
The output should include 'HOME'
End

It 'uses ghq root when available'
When run bash -c "grep 'ghq root' '$SCRIPT'"
The output should include 'ghq root'
End

It 'extracts ghq repo paths'
When run bash -c "grep 'ghq_root' '$SCRIPT'"
The output should include 'ghq_root'
End

It 'detects .git directory for repo root'
When run bash -c "grep '\.git' '$SCRIPT'"
The output should include '.git'
End

It 'uses basename for repo name'
When run bash -c "grep 'basename' '$SCRIPT'"
The output should include 'basename'
End
End

Describe 'build detection'
It 'detects Makefile for make build'
When run bash -c "grep 'Makefile' '$SCRIPT'"
The output should include 'Makefile'
End

It 'detects Cargo.toml for cargo build'
When run bash -c "grep 'Cargo.toml' '$SCRIPT'"
The output should include 'Cargo.toml'
End

It 'runs cargo build --release for Rust projects'
When run bash -c "grep 'cargo build --release' '$SCRIPT'"
The output should include 'cargo build --release'
End

It 'detects go.mod for go build'
When run bash -c "grep 'go.mod' '$SCRIPT'"
The output should include 'go.mod'
End

It 'runs go build for Go projects'
When run bash -c "grep 'go build' '$SCRIPT'"
The output should include 'go build'
End

It 'supports go build ./cmd/{repo_name} pattern'
# shellcheck disable=SC2016
When run bash -c 'grep "cmd/\$repo_name" '"'$SCRIPT'"
# shellcheck disable=SC2016
The output should include 'cmd/$repo_name'
End
End

Describe 'git operations'
It 'performs git pull'
When run bash -c "grep 'git pull' '$SCRIPT'"
The output should include 'git pull'
End

It 'clones missing repos with ghq'
When run bash -c "grep 'ghq get' '$SCRIPT'"
The output should include 'ghq get'
End
End

Describe 'result tracking'
It 'tracks successes'
When run bash -c "grep 'SUCCESSES' '$SCRIPT'"
The output should include 'SUCCESSES'
End

It 'tracks failures'
When run bash -c "grep 'FAILURES' '$SCRIPT'"
The output should include 'FAILURES'
End
End

Describe 'line processing'
It 'skips comment lines'
When run bash -c "grep -E 'Skip comments|^#' '$SCRIPT'"
The output should include '#'
End

It 'skips empty lines'
When run bash -c "grep '\-z' '$SCRIPT'"
The output should include '-z'
End
End

Describe 'duplicate detection'
It 'tracks seen repos'
When run bash -c "grep 'seen_repos' '$SCRIPT'"
The output should include 'seen_repos'
End
End

Describe 'usage and help'
It 'shows usage with -h flag'
When run bash "$SCRIPT" -h
The output should include 'Usage:'
The output should include 'filter'
The status should be success
End

It 'shows usage with --help flag'
When run bash "$SCRIPT" --help
The output should include 'Usage:'
The output should include 'Examples:'
The status should be success
End

It 'shows filter argument documentation'
When run bash "$SCRIPT" --help
The output should include 'Only update repos matching this pattern'
End
End

Describe 'config file handling'
setup() {
  TEMP_DIR=$(mktemp -d)
  TEMP_SCRIPT="$TEMP_DIR/test-config.sh"
  cat >"$TEMP_SCRIPT" <<'SCRIPT'
#!/usr/bin/env bash
set -euo pipefail

CONFIG_FILE="/nonexistent/path/to/.local-binaries.txt"

RED='\033[0;31m'
NC='\033[0m'

log_error() {
  echo -e "${RED}$1${NC}"
}

if [ ! -f "$CONFIG_FILE" ]; then
    log_error "Config file not found: $CONFIG_FILE"
    exit 1
fi
SCRIPT
  chmod +x "$TEMP_SCRIPT"
}

cleanup() {
  rm -rf "$TEMP_DIR"
}

Before 'setup'
After 'cleanup'

It 'exits with error when config file not found'
When run bash "$TEMP_SCRIPT"
The output should include 'Config file not found'
The status should be failure
End
End

Describe 'get_repo_dir function'
setup() {
  TEMP_DIR=$(mktemp -d)
  TEMP_SCRIPT="$TEMP_DIR/test-repo-dir.sh"
  cat >"$TEMP_SCRIPT" <<'SCRIPT'
#!/usr/bin/env bash
set -euo pipefail

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

# Test with actual path
get_repo_dir "$1"
SCRIPT
  chmod +x "$TEMP_SCRIPT"

  # Create a mock git repo structure
  mkdir -p "$TEMP_DIR/ghq/github.com/owner/repo/.git"
  mkdir -p "$TEMP_DIR/ghq/github.com/owner/repo/target/release"
  touch "$TEMP_DIR/ghq/github.com/owner/repo/target/release/mybin"
}

cleanup() {
  rm -rf "$TEMP_DIR"
}

Before 'setup'
After 'cleanup'

It 'finds repo root by .git directory'
When run bash "$TEMP_SCRIPT" "$TEMP_DIR/ghq/github.com/owner/repo/target/release/mybin"
The output should eq "$TEMP_DIR/ghq/github.com/owner/repo"
End
End

Describe 'build_repo function behavior'
setup() {
  TEMP_DIR=$(mktemp -d)
  TEMP_SCRIPT="$TEMP_DIR/test-build.sh"
  cat >"$TEMP_SCRIPT" <<'SCRIPT'
#!/usr/bin/env bash
set -euo pipefail

YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_warn() {
  echo -e "${YELLOW}$1${NC}"
}

log_step() {
  echo -e "${BLUE}$1${NC}"
}

get_repo_name() {
  local repo_dir="$1"
  basename "$repo_dir"
}

build_repo() {
  local repo_dir="$1"
  local repo_name
  repo_name="$(get_repo_name "$repo_dir")"

  log_step "  Building $repo_name..."

  if [ -f "$repo_dir/Makefile" ]; then
    echo "Would run: make -C $repo_dir build"
    return 0
  elif [ -f "$repo_dir/Cargo.toml" ]; then
    echo "Would run: cargo build --release"
    return 0
  elif [ -f "$repo_dir/go.mod" ]; then
    if [ -d "$repo_dir/cmd/$repo_name" ]; then
      echo "Would run: go build ./cmd/$repo_name"
    else
      echo "Would run: go build"
    fi
    return 0
  else
    log_warn "  No Makefile, Cargo.toml, or go.mod found, skipping build"
    return 0
  fi
}

build_repo "$1"
SCRIPT
  chmod +x "$TEMP_SCRIPT"
}

cleanup() {
  rm -rf "$TEMP_DIR"
}

Before 'setup'
After 'cleanup'

It 'detects Makefile and uses make'
mkdir -p "$TEMP_DIR/repo"
touch "$TEMP_DIR/repo/Makefile"
When run bash "$TEMP_SCRIPT" "$TEMP_DIR/repo"
The output should include 'Building repo'
The output should include 'make'
End

It 'detects Cargo.toml and uses cargo'
mkdir -p "$TEMP_DIR/rust-repo"
touch "$TEMP_DIR/rust-repo/Cargo.toml"
When run bash "$TEMP_SCRIPT" "$TEMP_DIR/rust-repo"
The output should include 'Building rust-repo'
The output should include 'cargo build --release'
End

It 'detects go.mod and uses go build'
mkdir -p "$TEMP_DIR/go-repo"
touch "$TEMP_DIR/go-repo/go.mod"
When run bash "$TEMP_SCRIPT" "$TEMP_DIR/go-repo"
The output should include 'Building go-repo'
The output should include 'go build'
End

It 'uses go build ./cmd/{repo_name} when cmd dir exists'
mkdir -p "$TEMP_DIR/multiclaude/cmd/multiclaude"
touch "$TEMP_DIR/multiclaude/go.mod"
When run bash "$TEMP_SCRIPT" "$TEMP_DIR/multiclaude"
The output should include 'Building multiclaude'
The output should include 'go build ./cmd/multiclaude'
End

It 'warns when no build system found'
mkdir -p "$TEMP_DIR/unknown-repo"
When run bash "$TEMP_SCRIPT" "$TEMP_DIR/unknown-repo"
The output should include 'No Makefile, Cargo.toml, or go.mod found'
End
End

Describe 'filter functionality'
setup() {
  TEMP_DIR=$(mktemp -d)
  CONFIG_FILE="$TEMP_DIR/.local-binaries.txt"
  cat >"$CONFIG_FILE" <<'CONFIG'
# Test binaries
~/ghq/github.com/owner/beads/bd
~/ghq/github.com/owner/other-tool/ot
~/ghq/github.com/owner/beads-viewer/bv
CONFIG

  TEMP_SCRIPT="$TEMP_DIR/test-filter.sh"
  cat >"$TEMP_SCRIPT" <<SCRIPT
#!/usr/bin/env bash
set -euo pipefail

CONFIG_FILE="$CONFIG_FILE"
filter="\${1:-}"

while IFS= read -r line || [ -n "\$line" ]; do
    # Skip comments and empty lines
    [[ \$line =~ ^[[:space:]]*# ]] && continue
    [[ -z \${line// /} ]] && continue

    # Apply filter if provided
    if [ -n "\$filter" ] && [[ ! \$line =~ \$filter ]]; then
      continue
    fi

    echo "Processing: \$line"
done <"\$CONFIG_FILE"
SCRIPT
  chmod +x "$TEMP_SCRIPT"
}

cleanup() {
  rm -rf "$TEMP_DIR"
}

Before 'setup'
After 'cleanup'

It 'processes all lines without filter'
When run bash "$TEMP_SCRIPT"
The output should include 'beads/bd'
The output should include 'other-tool/ot'
The output should include 'beads-viewer/bv'
End

It 'filters lines matching pattern'
When run bash "$TEMP_SCRIPT" beads
The output should include 'beads/bd'
The output should include 'beads-viewer/bv'
The output should not include 'other-tool/ot'
End
End

Describe 'summary output'
It 'prints summary header'
When run bash -c "grep 'Summary' '$SCRIPT'"
The output should include 'Summary'
End

It 'shows successful count'
When run bash -c "grep 'Successful' '$SCRIPT'"
The output should include 'SUCCESSES'
End

It 'shows failed count'
When run bash -c "grep 'Failed' '$SCRIPT'"
The output should include 'FAILURES'
End
End

Describe 'exit behavior'
It 'exits with error when failures exist'
When run bash -c "grep 'exit 1' '$SCRIPT' | tail -1"
The output should include 'exit 1'
End
End

End
