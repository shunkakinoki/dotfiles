#!/usr/bin/env bash
# Fleet lanes launch OpenCode only through this entrypoint, so the model
# contract stays fixed while T3 Code upgrades the npm `opencode` underneath.
set -euo pipefail

if [ "${1:-}" != "--model" ] || [ -z "${2:-}" ]; then
  echo "usage: opencode-lane --model <provider/model> [opencode args...]" >&2
  exit 64
fi
model="$2"
shift 2

exec opencode --model "$model" "$@"
