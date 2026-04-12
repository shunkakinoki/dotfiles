#!/usr/bin/env bash
# Copy git-ai config and inject git_path
# Usage: activate.sh <config_json> <git_path>
set -euo pipefail
CONFIG_JSON="$1"
GIT_PATH="$2"

mkdir -p ~/.git-ai
# Copy base config, then inject git_path via jq or sed
if command -v jq >/dev/null 2>&1; then
  jq --arg gp "$GIT_PATH" '. + {git_path: $gp}' "$CONFIG_JSON" >~/.git-ai/config.json
else
  sed "s|}$|,\"git_path\":\"$GIT_PATH\"}|" "$CONFIG_JSON" >~/.git-ai/config.json
fi
chmod 644 ~/.git-ai/config.json
