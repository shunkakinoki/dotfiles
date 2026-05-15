#!/usr/bin/env bash
# Copy managed Copilot config into the mutable runtime location.
# Usage: activate.sh <config_json>
set -euo pipefail

CONFIG_JSON="$1"

mkdir -p ~/.copilot
cp -f "$CONFIG_JSON" ~/.copilot/config.json
chmod 600 ~/.copilot/config.json
