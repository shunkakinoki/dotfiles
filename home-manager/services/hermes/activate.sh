#!/usr/bin/env bash
# Create Hermes directories and install runtime deps
# Usage: activate.sh <home_dir> <npm_bin>
set -euo pipefail
HOME_DIR="$1"
NPM_BIN="$2"

mkdir -p /tmp/hermes
mkdir -p "$HOME_DIR/.hermes"
mkdir -p "$HOME_DIR/.hermes/sessions"
mkdir -p "$HOME_DIR/.hermes/memories"
mkdir -p "$HOME_DIR/.hermes/skills"
mkdir -p "$HOME_DIR/.hermes/cron"
chmod 700 "$HOME_DIR/.hermes"

# Replace Nix-managed read-only systemd unit symlinks with writable copies
# so Hermes can auto-refresh them without PermissionError.
SYSTEMD_USER_DIR="$HOME_DIR/.config/systemd/user"
for unit in hermes-gateway.service hermes-dashboard.service hermes-dashboard-proxy.service; do
  unit_path="$SYSTEMD_USER_DIR/$unit"
  if [ -L "$unit_path" ]; then
    # Read the target file content, then replace symlink with writable copy
    content="$(cat "$unit_path" 2>/dev/null || true)"
    if [ -n "$content" ]; then
      rm -f "$unit_path"
      printf '%s\n' "$content" > "$unit_path"
      chmod 644 "$unit_path"
      echo "Replaced symlink $unit with writable copy"
    fi
  fi
done
systemctl --user daemon-reload 2>/dev/null || true

# Install hermes gateway runtime deps from pyproject.toml dependency group
HERMES_VENV="$HOME_DIR/ghq/github.com/NousResearch/hermes-agent/.venv"
if [ -d "$HERMES_VENV" ]; then
  uv pip install --python "$HERMES_VENV/bin/python" \
    --group hermes \
    --project "$HOME_DIR/dotfiles" 2>/dev/null || true
fi

# Build the dashboard with the npm version required by the Hermes checkout.
# The host-wide npm config omits optional dependencies, but Vite/Rolldown needs
# its platform binding to be present in the production bundle.
HERMES_REPO="$HOME_DIR/ghq/github.com/NousResearch/hermes-agent"
if [ -d "$HERMES_REPO/web" ] && [ -x "$NPM_BIN" ]; then
  if ! (
    cd "$HERMES_REPO"
    NPM_CONFIG_INCLUDE=optional NPM_CONFIG_IGNORE_SCRIPTS=false \
      "$NPM_BIN" install --workspace web --include=optional --ignore-scripts=false
    NPM_CONFIG_INCLUDE=optional NPM_CONFIG_IGNORE_SCRIPTS=false \
      "$NPM_BIN" run build --workspace web
  ); then
    echo "Warning: Hermes dashboard build failed; keeping the previous bundle" >&2
  fi
fi
