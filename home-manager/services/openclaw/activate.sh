#!/usr/bin/env bash
# Create OpenClaw directories with correct permissions
# Usage: activate.sh <home_dir>
set -euo pipefail
HOME_DIR="$1"

mkdir -p /tmp/openclaw
mkdir -p "$HOME_DIR/.openclaw"
mkdir -p "$HOME_DIR/.openclaw/plugins"
mkdir -p "$HOME_DIR/.openclaw/agents/main/sessions"
mkdir -p "$HOME_DIR/.openclaw/credentials"
chmod 700 "$HOME_DIR/.openclaw"
