#!/usr/bin/env bash
set -euo pipefail

base="${T3CODE_HOME:-$HOME/.t3}"
if [ ! -f "$base/runtime/service-state.json" ] && [ ! -x "${T3_REAL_CLI:-$HOME/.bun/bin/t3}" ]; then
  # Boot activation can precede the managed package installer. The existing
  # connect timer repeats setup once the CLI and browser are installed.
  echo "T3 CLI is not installed; deferring browser setup to the connect timer."
  exit 0
fi

# Keep the caller's T3 home under privilege escalation; the dispatcher selects
# the active service CLI and its matching libraries instead of root's install.
command=(env "PATH=$PATH" "HOME=$HOME" "T3CODE_HOME=$base" DEBIAN_FRONTEND=noninteractive "${T3_BROWSER_CLI:?}" browser setup)
if [ "$(id -u)" = 0 ]; then
  exec "${command[@]}"
fi
exec sudo -n "${command[@]}"
