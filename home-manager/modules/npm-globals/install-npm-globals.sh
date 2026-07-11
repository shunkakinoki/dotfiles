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

# Current-platform tokens used to recognise the native optionalDependency that
# actually carries a package's binary (e.g. *-darwin-arm64, @esbuild/linux-x64).
case "$(uname -s)" in
Darwin) PLATFORM_OS="darwin" ;;
Linux) PLATFORM_OS="linux" ;;
*) PLATFORM_OS="" ;;
esac
case "$(uname -m)" in
arm64 | aarch64) PLATFORM_CPU="arm64" ;;
x86_64 | amd64) PLATFORM_CPU="x64" ;;
*) PLATFORM_CPU="" ;;
esac

# Prints the name of a platform-native optionalDependency declared in the given
# package.json that is NOT installed, or nothing if all present / none declared.
# Emits "<native-dep-name> <declaring-version>" so callers can install the exact
# binary that bun dropped, at the version that matches its declaring wrapper.
missing_native_from_pkg() {
  local pj="$1"
  [ -f "$pj" ] || return 0
  local opt_deps name decl_ver
  opt_deps=$(jq -r '.optionalDependencies // {} | keys[]' "$pj" 2>/dev/null || true)
  [ -n "$opt_deps" ] || return 0
  decl_ver=$(jq -r '.version // empty' "$pj" 2>/dev/null || true)
  while IFS= read -r name; do
    [ -z "$name" ] && continue
    # Only weigh native deps targeting this platform.
    case "$name" in
    *"$PLATFORM_OS"*"$PLATFORM_CPU"* | *"$PLATFORM_CPU"*"$PLATFORM_OS"*) ;;
    *) continue ;;
    esac
    [ -d "${GLOBAL_MODULES}/${name}" ] && continue
    printf '%s %s\n' "$name" "$decl_ver"
    return 0
  done <<<"$opt_deps"
}

# Candidate package.json paths that may declare a package's real native binary:
# the package itself, plus its direct dependencies (thin wrappers hide the binary
# one level down, e.g. tokscale -> @tokscale/cli -> @tokscale/cli-darwin-arm64).
native_candidate_pkgs() {
  local dep="$1"
  local pj="${GLOBAL_MODULES}/${dep}/package.json"
  printf '%s\n' "$pj"
  local child
  while IFS= read -r child; do
    [ -z "$child" ] && continue
    printf '%s\n' "${GLOBAL_MODULES}/${child}/package.json"
  done < <(jq -r '.dependencies // {} | keys[]' "$pj" 2>/dev/null || true)
}

# Returns 0 when a package (or its immediate wrapper dependency) declares a
# platform-native optionalDependency for the current OS/CPU that is not
# installed. Many CLIs ship their real binary this way; a version-only skip would
# otherwise leave such a package "installed" yet non-functional (bun silently
# drops these transitive optional deps during global installs).
missing_native_optional_dep() {
  local dep="$1"
  [ -f "${GLOBAL_MODULES}/${dep}/package.json" ] || return 1
  [ -n "$PLATFORM_OS" ] && [ -n "$PLATFORM_CPU" ] || return 1

  local pj
  while IFS= read -r pj; do
    [ -n "$(missing_native_from_pkg "$pj")" ] && return 0
  done < <(native_candidate_pkgs "$dep")
  return 1
}

# Directly install the platform-native binary package that bun dropped for a
# wrapper dep, at the version its declaring package pins, so wrapper and binary
# always match. Returns 0 when the binary is present afterwards. Preferred over
# reinstalling the wrapper, which just re-triggers the same bun drop.
repair_native_optional_dep() {
  local dep="$1"
  local pj found native decl_ver spec
  while IFS= read -r pj; do
    found=$(missing_native_from_pkg "$pj")
    [ -n "$found" ] && break
  done < <(native_candidate_pkgs "$dep")
  [ -n "$found" ] || return 1

  native="${found%% *}"
  decl_ver="${found##* }"
  spec="$native"
  [ -n "$decl_ver" ] && spec="${native}@${decl_ver}"
  echo "Installing missing native binary: $spec"
  timeout 600 bun add --global "$spec" --minimum-release-age 0 2>/dev/null ||
    echo "Install failed: $spec" >&2
  purge_bun_npm_shim
  [ -d "${GLOBAL_MODULES}/${native}" ]
}

# Remove the npm "bun" wrapper package from global node_modules.
# Some transitive deps pull in the "bun" npm package whose postinstall
# downloads a bun binary. When that postinstall is skipped/fails, it leaves
# a stub .bin/bun shim that shadows the real system bun, breaking every
# subsequent postinstall that shells out to bun (e.g. @railway/cli).
purge_bun_npm_shim() {
  local gm="${HOME}/.bun/install/global/node_modules"
  if [ -d "${gm}/bun" ]; then
    rm -rf "${gm}/bun"
    rm -f "${gm}/.bin/bun" "${gm}/.bin/bunx"
    echo "Removed broken bun npm shim from global node_modules"
  fi
}

run_postinstall_if_needed() {
  local dep="$1"
  local dep_dir="${GLOBAL_MODULES}/${dep}"
  local pj="${dep_dir}/package.json"
  [ -f "$pj" ] || return 0
  local postinstall
  postinstall=$(jq -r '.scripts.postinstall // empty' "$pj" 2>/dev/null || true)
  [ -n "$postinstall" ] || return 0
  local bin_dir="${dep_dir}/bin"
  if [ -d "$bin_dir" ]; then
    local has_native=false
    for f in "$bin_dir"/*; do
      [ -f "$f" ] || continue
      case "$f" in *.js | *.cjs | *.mjs | *.exe) continue ;; esac
      has_native=true
      break
    done
    if $has_native; then
      return 0
    fi
  fi
  echo "Running postinstall for $dep (native binary missing)..."
  if command -v node &>/dev/null; then
    (cd "$dep_dir" && node -e "
      const {execSync} = require('child_process');
      execSync($(printf '%s' "$postinstall" | jq -Rs .), {stdio: 'inherit', cwd: '.'});
    ") 2>&1 || echo "Postinstall failed for $dep" >&2
  fi
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

purge_bun_npm_shim

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
        # Version matches, but only skip if the native binary is actually
        # present. Drop a broken install so the reinstall below refetches it.
        if missing_native_optional_dep "$dep"; then
          echo "$dep@$installed_ver installed but native binary missing"
          # Install the dropped binary directly; reinstalling the wrapper just
          # re-triggers the same bun transitive-optional drop.
          if repair_native_optional_dep "$dep"; then
            echo "$dep native binary repaired in place"
            run_postinstall_if_needed "$dep"
            continue
          fi
          echo "$dep native binary repair failed, reinstalling wrapper"
          rm -rf "${GLOBAL_MODULES:?}/${dep}"
          MISSING+=("$dep")
          continue
        fi
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
    timeout 600 bun add --global "$dep" --minimum-release-age 0 2>/dev/null || echo "Install failed: $dep"
    purge_bun_npm_shim
    run_postinstall_if_needed "$dep"
    # Heal in the same run: bun drops transitive platform binaries on fresh
    # global installs, so repair immediately instead of waiting for next activation.
    if missing_native_optional_dep "$dep"; then
      if repair_native_optional_dep "$dep"; then
        run_postinstall_if_needed "$dep"
      else
        echo "Native binary repair failed: $dep" >&2
      fi
    fi
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
    purge_bun_npm_shim
    echo "Applied dependency overrides to global install"
  fi
fi

# Install platform-matching optionalDependencies (e.g. claude-code-darwin-arm64).
# Bun's transitive-optional resolution silently drops these when the parent's
# postinstall is blocked by ignoreScripts, so we install the matching variant
# directly. MUST run after the overrides `bun install` above, which prunes
# optional deps. Filter by os-arch[-libc] suffix in the package name.
OPTIONAL_DEPS=$(jq -r '.optionalDependencies // {} | to_entries[] | "\(.key)=\(.value)"' "$PACKAGE_JSON" 2>/dev/null || true)
if [ -n "$OPTIONAL_DEPS" ]; then
  PLATFORM_OS=""
  case "$(uname -s)" in
  Darwin) PLATFORM_OS="darwin" ;;
  Linux) PLATFORM_OS="linux" ;;
  *) PLATFORM_OS="$(uname -s | tr '[:upper:]' '[:lower:]')" ;;
  esac
  PLATFORM_ARCH=""
  case "$(uname -m)" in
  arm64 | aarch64) PLATFORM_ARCH="arm64" ;;
  x86_64) PLATFORM_ARCH="x64" ;;
  *) PLATFORM_ARCH="$(uname -m)" ;;
  esac
  PLATFORM_SUFFIX="${PLATFORM_OS}-${PLATFORM_ARCH}"
  PLATFORM_MUSL_SUFFIX="${PLATFORM_SUFFIX}-musl"

  while IFS= read -r entry; do
    dep="${entry%%=*}"
    [ -z "$dep" ] && continue
    # Match exact platform variant. Skip musl on darwin/win32.
    if [[ $dep == *"-${PLATFORM_SUFFIX}" ]]; then
      :
    elif [ "$PLATFORM_OS" = "linux" ] && [[ $dep == *"-${PLATFORM_MUSL_SUFFIX}" ]]; then
      # Only install musl variant on actual musl systems (NixOS uses glibc by default).
      if ! ldd --version 2>&1 | grep -qi musl; then
        continue
      fi
    else
      continue
    fi
    val="${entry#*=}"
    # Resolve the spec to install and the exact version we expect on disk.
    # For plain semver ranges (claude-code pattern) bun resolves latest, so we
    # can't predict the version; want_ver stays empty and presence alone is fine.
    spec="$dep"
    want_ver=""
    if [[ $val == npm:* ]]; then
      # Aliased native binary (codex pattern): npm:@openai/codex@<ver>.
      # These packages are PUBLISHED as <base>@<ver>-<platform-suffix> (e.g.
      # @openai/codex@0.142.5-darwin-arm64) and only that suffixed tarball
      # carries the vendor binary. A bare <base>@<ver> pin (no suffix) silently
      # reinstalls the generic JS wrapper under the platform dir name -- no
      # binary -- and the CLI dies with "Missing optional dependency". So we
      # reconstruct the suffixed spec here regardless of how package.json pins it.
      alias_spec="${val#npm:}"     # @openai/codex@0.142.2
      base_name="${alias_spec%@*}" # @openai/codex
      base_ver="${alias_spec##*@}" # 0.142.2 (fallback if parent not installed)
      # Prefer the ACTUALLY INSTALLED parent version so the binary always matches
      # the wrapper even when the package.json pins have drifted behind it.
      base_pj="${GLOBAL_MODULES}/${base_name}/package.json"
      if [ -f "$base_pj" ]; then
        installed_base=$(jq -r '.version // empty' "$base_pj" 2>/dev/null || true)
        [ -n "$installed_base" ] && base_ver="$installed_base"
      fi
      suffix="${dep#"${base_name}"-}" # darwin-arm64
      if [ -n "$suffix" ] && [ "$suffix" != "$dep" ]; then
        want_ver="${base_ver}-${suffix}"
      else
        want_ver="$base_ver"
      fi
      spec="${dep}@npm:${base_name}@${want_ver}"
    fi
    # Consider the dep installed only when its payload is REAL. Bun's transitive
    # optional resolution can leave a phantom empty dir (passes -d, holds no
    # binary), and a stale/wrong-suffix pin leaves the generic wrapper (wrong
    # version). Both must be torn down and reinstalled, not skipped on -d alone.
    dep_pj="${GLOBAL_MODULES}/${dep}/package.json"
    if [ -f "$dep_pj" ]; then
      have_ver=$(jq -r '.version // empty' "$dep_pj" 2>/dev/null || true)
      if [ -z "$want_ver" ] || [ "$have_ver" = "$want_ver" ]; then
        echo "$dep@${have_ver:-unknown} already installed, skipping"
        continue
      fi
      echo "$dep@${have_ver:-unknown} installed, want $want_ver, reinstalling"
    elif [ -d "${GLOBAL_MODULES}/${dep}" ]; then
      echo "$dep present but empty (phantom dir), reinstalling"
    fi
    rm -rf "${GLOBAL_MODULES:?}/${dep}"
    # Bun's `bun add -g <pkg>` is a no-op if <pkg> is already in the global
    # package.json's optionalDependencies (it never materializes the dir).
    # Strip from optionalDependencies first so the add becomes a real install.
    if [ -f "$GLOBAL_PKG" ] && jq -e --arg dep "$dep" '.optionalDependencies | has($dep)' "$GLOBAL_PKG" >/dev/null 2>&1; then
      jq --arg dep "$dep" 'del(.optionalDependencies[$dep])' "$GLOBAL_PKG" >"${GLOBAL_PKG}.tmp" &&
        mv "${GLOBAL_PKG}.tmp" "$GLOBAL_PKG"
    fi
    echo "Installing platform-native: $spec"
    timeout 600 bun add --global "$spec" --minimum-release-age 0 2>/dev/null || echo "Install failed: $spec"
    purge_bun_npm_shim
    # Verify the payload actually materialized; bun can silently no-op.
    if [ ! -f "${GLOBAL_MODULES}/${dep}/package.json" ]; then
      echo "Warning: $dep still missing after install ($spec)" >&2
    fi
  done <<<"$OPTIONAL_DEPS"
fi

# Strip non-matching platform-variant entries from global optionalDependencies.
# Bun lists them but never materializes them (os/cpu mismatch), so they just
# accumulate and clutter the global package.json across runs.
if [ -f "$GLOBAL_PKG" ]; then
  STALE_OPTIONAL=$(jq -r '.optionalDependencies // {} | keys[]?' "$GLOBAL_PKG" 2>/dev/null || true)
  if [ -n "$STALE_OPTIONAL" ]; then
    while IFS= read -r dep; do
      [ -z "$dep" ] && continue
      if ! jq -e --arg dep "$dep" '.dependencies | has($dep)' "$GLOBAL_PKG" >/dev/null 2>&1; then
        jq --arg dep "$dep" 'del(.optionalDependencies[$dep])' "$GLOBAL_PKG" >"${GLOBAL_PKG}.tmp" &&
          mv "${GLOBAL_PKG}.tmp" "$GLOBAL_PKG"
      fi
    done <<<"$STALE_OPTIONAL"
  fi
  # Drop the optionalDependencies key entirely if now empty.
  if [ "$(jq -r '.optionalDependencies // {} | length' "$GLOBAL_PKG" 2>/dev/null)" = "0" ]; then
    jq 'del(.optionalDependencies)' "$GLOBAL_PKG" >"${GLOBAL_PKG}.tmp" &&
      mv "${GLOBAL_PKG}.tmp" "$GLOBAL_PKG"
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

echo "npm globals installation complete"
