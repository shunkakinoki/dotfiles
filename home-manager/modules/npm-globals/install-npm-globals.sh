#!/usr/bin/env bash

set -euo pipefail

# Skip during boot on Linux (SYSTEMCTL_BIN set by nix activation)
if [ -n "${SYSTEMCTL_BIN:-}" ] && [ "$("$SYSTEMCTL_BIN" is-system-running 2>/dev/null)" = "starting" ]; then
  echo "System is booting, skipping npm globals install"
  exit 0
fi

# Skip if offline
if ! timeout 3 bash -c 'exec 3<>/dev/tcp/1.1.1.1/53' 2>/dev/null; then
  echo "Network unavailable, skipping npm globals install"
  exit 0
fi

# Install npm global packages from package.json using bun
# Reads dependencies from ~/dotfiles/package.json and installs them globally

PACKAGE_JSON="${HOME}/dotfiles/package.json"

# Exit if no package.json exists
if [ ! -f "$PACKAGE_JSON" ]; then
  echo "No ${PACKAGE_JSON} found, skipping npm globals install"
  exit 0
fi

# Check for required tools
if ! command -v bun &>/dev/null; then
  echo "bun not found, skipping npm globals install"
  exit 0
fi

if ! command -v jq &>/dev/null; then
  echo "jq not found, skipping npm globals install"
  exit 0
fi

repair_sqlite3_native_binding() {
  local sqlite3_dir="${GLOBAL_MODULES}/sqlite3"
  local global_install_dir="${HOME}/.bun/install/global"
  local require_sqlite3='const sqlite3 = require("sqlite3"); if (!sqlite3.Database) process.exit(1);'

  if [ ! -d "$sqlite3_dir" ]; then
    return 0
  fi

  if command -v node &>/dev/null && (cd "$global_install_dir" && node -e "$require_sqlite3") >/dev/null 2>&1; then
    echo "sqlite3 native binding already loadable"
    return 0
  fi

  if ! command -v npm &>/dev/null; then
    echo "npm not found, cannot rebuild sqlite3 native binding" >&2
    return 1
  fi

  if ! command -v node &>/dev/null; then
    echo "node not found, cannot verify sqlite3 native binding" >&2
    return 1
  fi

  echo "Rebuilding sqlite3 native binding..."
  if ! (cd "$sqlite3_dir" && npm run install --foreground-scripts); then
    echo "sqlite3 native binding rebuild failed" >&2
    return 1
  fi

  if ! (cd "$global_install_dir" && node -e "$require_sqlite3") >/dev/null 2>&1; then
    echo "sqlite3 native binding is still not loadable after rebuild" >&2
    return 1
  fi

  echo "sqlite3 native binding rebuilt"
}

repair_claude_code_native_binary() {
  # @anthropic-ai/claude-code ships only a wrapper in bin/claude.exe; the real
  # binary comes from a platform-native optionalDependency installed by its
  # postinstall. The version-only skip above leaves a broken install in place
  # when that optional dep is missing (e.g. after an `omit=optional` install),
  # so reinstall to fetch the native binary.
  local claude_dir="${GLOBAL_MODULES}/@anthropic-ai/claude-code"
  local wanted

  if [ ! -d "$claude_dir" ]; then
    return 0
  fi

  if command -v claude &>/dev/null && claude --version >/dev/null 2>&1; then
    echo "claude native binary already loadable"
    return 0
  fi

  wanted=$(jq -r '.dependencies["@anthropic-ai/claude-code"] // empty' "$PACKAGE_JSON" 2>/dev/null || true)
  [ -z "$wanted" ] && wanted="latest"

  echo "Reinstalling @anthropic-ai/claude-code to fetch native binary..."
  bun pm -g trust @anthropic-ai/claude-code 2>/dev/null || true
  bun remove --global @anthropic-ai/claude-code 2>/dev/null || true
  if ! timeout 600 bun add --global "@anthropic-ai/claude-code@${wanted}"; then
    echo "claude-code reinstall failed" >&2
    return 1
  fi

  if ! (command -v claude &>/dev/null && claude --version >/dev/null 2>&1); then
    echo "claude native binary still not loadable after reinstall" >&2
    return 1
  fi

  echo "claude native binary repaired"
}

echo "Installing npm global packages from package.json using bun..."
cd "${HOME}/dotfiles"

# Trust postinstall scripts for packages listed in trustedDependencies before installing
TRUSTED_DEPS=$(jq -r '.trustedDependencies[]?' "$PACKAGE_JSON" 2>/dev/null || true)
if [ -n "$TRUSTED_DEPS" ]; then
  echo "Trusting postinstall scripts for: $TRUSTED_DEPS"
  echo "$TRUSTED_DEPS" | while read -r dep; do
    bun pm -g trust "$dep" 2>/dev/null || true
  done
fi

# Remove packages that are no longer declared in dotfiles/package.json
GLOBAL_PKG="${HOME}/.bun/install/global/package.json"
STALE=()
if [ -f "$GLOBAL_PKG" ]; then
  GLOBAL_DEPS=$(jq -r '.dependencies | keys[]?' "$GLOBAL_PKG" 2>/dev/null || true)
  if [ -n "$GLOBAL_DEPS" ]; then
    while IFS= read -r dep; do
      [ -z "$dep" ] && continue
      if ! jq -e --arg dep "$dep" '.dependencies | has($dep)' "$PACKAGE_JSON" >/dev/null 2>&1; then
        STALE+=("$dep")
      fi
    done <<<"$GLOBAL_DEPS"
  fi
fi

if [ "${#STALE[@]}" -gt 0 ]; then
  echo "Removing ${#STALE[@]} stale packages..."
  for dep in "${STALE[@]}"; do
    timeout 600 bun remove --global "$dep" 2>/dev/null || echo "Remove failed: $dep"
    if [ -f "$GLOBAL_PKG" ] && jq -e --arg dep "$dep" '.dependencies | has($dep)' "$GLOBAL_PKG" >/dev/null 2>&1; then
      jq --arg dep "$dep" 'del(.dependencies[$dep])' "$GLOBAL_PKG" >"${GLOBAL_PKG}.tmp" &&
        mv "${GLOBAL_PKG}.tmp" "$GLOBAL_PKG"
    fi
    rm -rf "${HOME}/.bun/install/global/node_modules/$dep"
  done
fi

# Build list of packages that need installing or updating
GLOBAL_MODULES="${HOME}/.bun/install/global/node_modules"
DEPS=$(jq -r '.dependencies | to_entries[] | "\(.key)=\(.value)"' "$PACKAGE_JSON" 2>/dev/null || true)
MISSING=()
if [ -n "$DEPS" ]; then
  while IFS= read -r entry; do
    dep="${entry%%=*}"
    wanted="${entry#*=}"
    # Extract minimum version from semver spec (e.g. "^2.1.92" -> "2.1.92")
    wanted_ver="${wanted//[^0-9.]/}"
    installed_ver=""
    pkg_json="${GLOBAL_MODULES}/${dep}/package.json"
    if [ -f "$pkg_json" ]; then
      installed_ver=$(jq -r '.version // empty' "$pkg_json" 2>/dev/null || true)
    fi
    if [ -n "$installed_ver" ] && [ -n "$wanted_ver" ]; then
      min_ver=$(printf '%s\n%s\n' "$wanted_ver" "$installed_ver" | sort -V | head -n1)
      if [ "$min_ver" = "$wanted_ver" ]; then
        echo "$dep@$installed_ver already installed, skipping"
        continue
      fi
    fi
    if [ -n "$installed_ver" ]; then
      echo "$dep@$installed_ver installed, want $wanted_ver, updating"
      MISSING+=("$dep")
    else
      MISSING+=("$dep")
    fi
  done <<<"$DEPS"
fi

# Install missing packages one by one
if [ "${#MISSING[@]}" -gt 0 ]; then
  echo "Installing ${#MISSING[@]} missing packages..."
  for dep in "${MISSING[@]}"; do
    timeout 600 bun add --global "$dep" 2>/dev/null || echo "Install failed: $dep"
  done
else
  echo "All npm global packages already installed"
fi

# Remove stale shims left behind by prior Bun global installs
BUN_BIN="${HOME}/.bun/bin"
if [ -d "$BUN_BIN" ]; then
  find "$BUN_BIN" -mindepth 1 -maxdepth 1 -type l 2>/dev/null | while read -r shim; do
    if [ ! -e "$shim" ]; then
      rm -f "$shim"
      echo "Removed dangling bun shim: $(basename "$shim")"
    fi
  done
fi

# Apply dependency overrides to the global install
# Bun's flat hoisting can resolve incompatible versions (e.g. pino@10 vs pino-http@10.5)
OVERRIDES=$(jq -c '.overrides // empty' "$PACKAGE_JSON" 2>/dev/null || true)
if [ -n "$OVERRIDES" ]; then
  if [ -f "$GLOBAL_PKG" ]; then
    jq --argjson overrides "$OVERRIDES" '.overrides = $overrides' "$GLOBAL_PKG" >"${GLOBAL_PKG}.tmp" &&
      mv "${GLOBAL_PKG}.tmp" "$GLOBAL_PKG"
    (cd "${HOME}/.bun/install/global" && bun install 2>/dev/null || true)
    echo "Applied dependency overrides to global install"
  fi
fi

# Deduplicate overridden packages from nested node_modules
# Bun can install the same package at both top-level and nested locations.
# When packages use Symbols (like pino), two copies create incompatible
# instances. Remove nested copies of any overridden package so everything
# resolves to the single top-level version.
GLOBAL_MODULES="${HOME}/.bun/install/global/node_modules"
for pkg in $(echo "$OVERRIDES" | jq -r 'keys[]' 2>/dev/null); do
  find "$GLOBAL_MODULES" -mindepth 3 -maxdepth 4 -type d -name "$pkg" \
    -path "*/node_modules/$pkg" \
    ! -path "$GLOBAL_MODULES/$pkg" 2>/dev/null | while read -r nested; do
    rm -r "$nested"
    echo "Deduplicated nested $pkg: $nested"
  done
done

if ! repair_sqlite3_native_binding; then
  echo "Warning: sqlite3 native binding repair failed" >&2
fi

if ! repair_claude_code_native_binary; then
  echo "Warning: claude-code native binary repair failed" >&2
fi

echo "npm globals installation complete"
