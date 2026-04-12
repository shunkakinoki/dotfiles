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

echo "npm globals installation complete"
