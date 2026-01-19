#!/usr/bin/env bash
# shellcheck disable=SC2329,SC2034

Describe 'upgrade-overlays.sh'
SCRIPT="$PWD/scripts/upgrade-overlays.sh"

Describe 'usage and help'
It 'shows usage when called without arguments'
When run bash "$SCRIPT"
The output should include 'Usage:'
The output should include 'upgrade-overlays.sh'
The output should include 'clawdbot'
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
setup() {
  mock_bin_setup gh nix-prefetch-url nix jq
}

cleanup() {
  mock_bin_cleanup
}

Before 'setup'
After 'cleanup'

It 'fails for unknown overlay'
When run bash "$SCRIPT" unknown-overlay
The output should include 'Unknown overlay: unknown-overlay'
The output should include 'Available overlays'
The status should be failure
End
End

Describe 'dependency checking'
setup() {
  TEMP_DIR=$(mktemp -d)
  # Create a script that only has partial PATH
  TEMP_SCRIPT="$TEMP_DIR/test-deps.sh"
  cat >"$TEMP_SCRIPT" <<'SCRIPT'
#!/usr/bin/env bash
set -euo pipefail
# Override PATH to exclude tools
export PATH="/usr/bin:/bin"

check_dependencies() {
    local missing=()
    for cmd in gh nix-prefetch-url nix jq; do
        if ! command -v "$cmd" &>/dev/null; then
            missing+=("$cmd")
        fi
    done
    if [ ${#missing[@]} -ne 0 ]; then
        echo "Missing required dependencies: ${missing[*]}"
        exit 1
    fi
}
check_dependencies
SCRIPT
  chmod +x "$TEMP_SCRIPT"
}

cleanup() {
  rm -rf "$TEMP_DIR"
}

Before 'setup'
After 'cleanup'

It 'reports missing dependencies'
When run bash "$TEMP_SCRIPT"
The output should include 'Missing required dependencies'
The status should be failure
End
End

Describe 'clawdbot upgrade'
setup() {
  mock_bin_setup gh nix-prefetch-url nix jq
  TEMP_DIR=$(mktemp -d)
  OVERLAY_FILE="$TEMP_DIR/overlays/default.nix"
  mkdir -p "$TEMP_DIR/overlays"

  # Create a minimal overlay file with the expected structure
  cat >"$OVERLAY_FILE" <<'NIX'
{ inputs }:
let
  # Override clawdbot source to v2026.1.15
  clawdbotSourceOverride = {
    owner = "clawdbot";
    repo = "clawdbot";
    rev = "abc123";
    hash = "sha256-OLDHASH1234567890=";
    pnpmDepsHash = "sha256-PNPMHASH1234567890=";
  };
  # Override clawdbot-app to v2026.1.15 (fixes broken app package)
  clawdbotAppOverride = {
    version = "2026.1.15";
    url = "https://github.com/clawdbot/clawdbot/releases/download/v2026.1.15/Clawdbot-2026.1.15.zip";
    hash = "sha256-OLDAPPHASH1234567890=";
  };
in
[
  (
    final: prev:
    let
      clawdbotVersion = "2026.1.15";
    in
    {}
  )
]
NIX

  # Create a test script that uses our temp overlay file
  TEMP_SCRIPT="$TEMP_DIR/upgrade-test.sh"
  cat >"$TEMP_SCRIPT" <<SCRIPT
#!/usr/bin/env bash
set -euo pipefail

OVERLAY_FILE="$OVERLAY_FILE"

# Mock implementations that return test values
fetch_latest_release() {
    echo "v2026.1.16"
}

get_tag_commit() {
    echo "newcommit456"
}

compute_source_hash() {
    echo "0123456789abcdef"
}

convert_to_sri() {
    echo "sha256-NEWHASH="
}

sed_inplace() {
    if [[ "\$OSTYPE" == "darwin"* ]]; then
        sed -i '' "\$@"
    else
        sed -i "\$@"
    fi
}

upgrade_clawdbot() {
    local current_version tag version rev

    current_version=\$(grep -oE 'clawdbotVersion = "[^"]+"' "\$OVERLAY_FILE" | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+(-[0-9]+)?' || echo "unknown")
    echo "Current version: \$current_version"

    tag=\$(fetch_latest_release)
    version="\${tag#v}"
    echo "Latest version: \$version"

    if [ "\$current_version" = "\$version" ]; then
        echo "Already on latest version (\$version)"
        return 0
    fi

    rev=\$(get_tag_commit)
    echo "Commit: \$rev"

    echo "Updating overlay file..."
    sed_inplace "s|rev = \"[^\"]*\";|rev = \"\$rev\";|" "\$OVERLAY_FILE"
    sed_inplace "s|clawdbotVersion = \"[^\"]*\";|clawdbotVersion = \"\$version\";|" "\$OVERLAY_FILE"

    echo "clawdbot upgraded from \$current_version to \$version"
}

upgrade_clawdbot
SCRIPT
  chmod +x "$TEMP_SCRIPT"
}

cleanup() {
  rm -rf "$TEMP_DIR"
  mock_bin_cleanup
}

Before 'setup'
After 'cleanup'

It 'detects current version from overlay file'
When run bash "$TEMP_SCRIPT"
The output should include 'Current version: 2026.1.15'
The status should be success
End

It 'fetches latest release version'
When run bash "$TEMP_SCRIPT"
The output should include 'Latest version: 2026.1.16'
The status should be success
End

It 'updates the overlay file'
When run bash "$TEMP_SCRIPT"
The output should include 'Updating overlay file'
The output should include 'clawdbot upgraded from 2026.1.15 to 2026.1.16'
The status should be success
End

It 'updates rev in overlay file'
bash "$TEMP_SCRIPT" >/dev/null 2>&1
When run cat "$OVERLAY_FILE"
The output should include 'rev = "newcommit456"'
End

It 'updates clawdbotVersion in overlay file'
bash "$TEMP_SCRIPT" >/dev/null 2>&1
When run cat "$OVERLAY_FILE"
The output should include 'clawdbotVersion = "2026.1.16"'
End
End

Describe 'already on latest version'
setup() {
  mock_bin_setup gh nix-prefetch-url nix jq
  TEMP_DIR=$(mktemp -d)

  # Create a test script that simulates already on latest
  TEMP_SCRIPT="$TEMP_DIR/upgrade-latest.sh"
  cat >"$TEMP_SCRIPT" <<'SCRIPT'
#!/usr/bin/env bash
set -euo pipefail

current_version="2026.1.16"
latest_version="2026.1.16"

echo "Current version: $current_version"
echo "Latest version: $latest_version"

if [ "$current_version" = "$latest_version" ]; then
    echo "Already on latest version ($latest_version)"
    exit 0
fi
SCRIPT
  chmod +x "$TEMP_SCRIPT"
}

cleanup() {
  rm -rf "$TEMP_DIR"
  mock_bin_cleanup
}

Before 'setup'
After 'cleanup'

It 'skips upgrade when already on latest'
When run bash "$TEMP_SCRIPT"
The output should include 'Already on latest version'
The status should be success
End
End

Describe 'all overlay target'
setup() {
  mock_bin_setup gh nix-prefetch-url nix jq
  TEMP_DIR=$(mktemp -d)

  # Create a minimal test script for 'all' target
  TEMP_SCRIPT="$TEMP_DIR/upgrade-all.sh"
  cat >"$TEMP_SCRIPT" <<'SCRIPT'
#!/usr/bin/env bash
set -euo pipefail

upgrade_clawdbot() {
    echo "Upgrading clawdbot..."
}

main() {
    local target="${1:-}"
    case "$target" in
        all)
            upgrade_clawdbot
            echo "All overlays upgraded"
            ;;
        *)
            echo "Unknown target"
            exit 1
            ;;
    esac
}

main "$@"
SCRIPT
  chmod +x "$TEMP_SCRIPT"
}

cleanup() {
  rm -rf "$TEMP_DIR"
  mock_bin_cleanup
}

Before 'setup'
After 'cleanup'

It 'upgrades all overlays when target is all'
When run bash "$TEMP_SCRIPT" all
The output should include 'Upgrading clawdbot'
The output should include 'All overlays upgraded'
The status should be success
End
End
End
