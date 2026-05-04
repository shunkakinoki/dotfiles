#!/usr/bin/env bash
# Create Hermes directories with correct permissions
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
