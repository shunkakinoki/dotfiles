#!/usr/bin/env bash

set -euo pipefail

# Install cargo global packages from Cargo.toml
# Reads dependencies from ~/dotfiles/Cargo.toml and installs them globally

CARGO_TOML="${HOME}/dotfiles/Cargo.toml"

# Exit if no Cargo.toml exists
if [ ! -f "$CARGO_TOML" ]; then
  echo "No ${CARGO_TOML} found, skipping cargo globals install"
  exit 0
fi

# Check for required tools
if ! command -v cargo &>/dev/null; then
  echo "cargo not found, skipping cargo globals install"
  exit 0
fi

if ! command -v dasel &>/dev/null; then
  echo "dasel not found, skipping cargo globals install"
  exit 0
fi

if ! command -v jq &>/dev/null; then
  echo "jq not found, skipping cargo globals install"
  exit 0
fi

# Parse dependencies from Cargo.toml (supports version strings and git tables)
DEPS=$(dasel -f "$CARGO_TOML" -r toml -w json 'dependencies' 2>/dev/null | jq -c 'to_entries[]' 2>/dev/null || true)

if [ -z "$DEPS" ]; then
  echo "No dependencies found in Cargo.toml"
  exit 0
fi

# Get currently installed packages (cargo's native cache)
INSTALLED=$(cargo install --list 2>/dev/null || true)
declare -A INSTALLED_MAP=()

while read -r line; do
  case "$line" in
  "" | " "*) continue ;;
  *)
    if [[ $line =~ ^([^[:space:]]+)[[:space:]]v([^:]+): ]]; then
      INSTALLED_MAP["${BASH_REMATCH[1]}"]="${BASH_REMATCH[2]}"
    fi
    ;;
  esac
done <<<"$INSTALLED"

while read -r dep; do
  [ -z "$dep" ] && continue
  NAME=$(echo "$dep" | jq -r '.key')
  KIND=$(echo "$dep" | jq -r 'if (.value|type)=="string" then "version" elif (.value.version) then "version" elif (.value.git) then "git" else "unknown" end')

  case "$KIND" in
  version)
    VERSION=$(echo "$dep" | jq -r 'if (.value|type)=="string" then .value else .value.version end')
    if [ -n "$NAME" ] && [ -n "$VERSION" ] && [ "$VERSION" != "null" ]; then
      # Check if already installed at this version (format: "crate_name v1.2.3:")
      if [ "${INSTALLED_MAP[$NAME]:-}" = "$VERSION" ]; then
        echo "$NAME@$VERSION already installed, skipping"
        continue
      fi
      echo "Installing $NAME@$VERSION..."
      if ! cargo install "$NAME" --version "$VERSION" --locked 2>&1; then
        if ! cargo install "$NAME" --version "$VERSION" 2>&1; then
          echo "Failed to install $NAME@$VERSION, skipping..."
        fi
      fi
    fi
    ;;
  git)
    GIT_URL=$(echo "$dep" | jq -r '.value.git')
    BRANCH=$(echo "$dep" | jq -r '.value.branch // empty')
    TAG=$(echo "$dep" | jq -r '.value.tag // empty')
    REV=$(echo "$dep" | jq -r '.value.rev // empty')
    if [ -n "$NAME" ] && [ -n "$GIT_URL" ]; then
      if [ -n "${INSTALLED_MAP[$NAME]:-}" ]; then
        echo "$NAME already installed (git), skipping"
        continue
      fi
      echo "Installing $NAME from $GIT_URL..."
      INSTALL_ARGS=(--git "$GIT_URL")
      if [ -n "$REV" ]; then
        INSTALL_ARGS+=(--rev "$REV")
      elif [ -n "$TAG" ]; then
        INSTALL_ARGS+=(--tag "$TAG")
      elif [ -n "$BRANCH" ]; then
        INSTALL_ARGS+=(--branch "$BRANCH")
      fi
      if ! cargo install "$NAME" "${INSTALL_ARGS[@]}" --locked 2>&1; then
        if ! cargo install "$NAME" "${INSTALL_ARGS[@]}" 2>&1; then
          echo "Failed to install $NAME from git, skipping..."
        fi
      fi
    fi
    ;;
  *)
    if [ -n "$NAME" ]; then
      echo "Skipping $NAME (unsupported dependency format)"
    fi
    ;;
  esac
done <<<"$DEPS"

echo "cargo globals check complete"
