#!/usr/bin/env bash
# Create Hermes directories and install runtime deps
# Usage: activate.sh <home_dir>
set -euo pipefail
HOME_DIR="$1"

mkdir -p /tmp/hermes
mkdir -p "$HOME_DIR/.hermes"
mkdir -p "$HOME_DIR/.hermes/sessions"
mkdir -p "$HOME_DIR/.hermes/memories"
mkdir -p "$HOME_DIR/.hermes/skills"
mkdir -p "$HOME_DIR/.hermes/cron"
chmod 700 "$HOME_DIR/.hermes"

# Install hermes gateway runtime deps from pyproject.toml dependency group
HERMES_VENV="$HOME_DIR/ghq/github.com/NousResearch/hermes-agent/.venv"
if [ -d "$HERMES_VENV" ]; then
  uv pip install --python "$HERMES_VENV/bin/python" \
    --group hermes \
    --project "$HOME_DIR/dotfiles" 2>/dev/null || true
fi
