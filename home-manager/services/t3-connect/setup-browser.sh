#!/usr/bin/env bash
set -euo pipefail

base="${T3CODE_HOME:-$HOME/.t3}"
if [ ! -f "$base/runtime/service-state.json" ] && [ ! -x "${T3_REAL_CLI:-$HOME/.bun/bin/t3}" ]; then
  # Boot activation can precede the managed package installer. The existing
  # connect timer repeats setup once the CLI and browser are installed.
  echo "T3 CLI is not installed; deferring browser setup to the connect timer."
  exit 0
fi

# The npm `latest` release predates the `browser` subcommand that nightly
# runtimes ship; it rejects `browser setup` and would fail activation. The
# connect timer repeats setup once `t3 update` moves to a runtime that has it.
help="$(env "T3CODE_HOME=$base" "${T3_BROWSER_CLI:?}" --help 2>&1 || true)"
if ! grep -qE '^ +browser ' <<<"$help"; then
  echo "T3 CLI has no browser command; deferring browser setup to the connect timer."
  exit 0
fi

# Upstream setup unconditionally writes an AppArmor profile; containers and
# hosts without AppArmor have no profile directory, so the write fails.
if [ ! -d "${T3_APPARMOR_DIR:-/etc/apparmor.d}" ]; then
  echo "AppArmor is not available; skipping T3 browser setup."
  exit 0
fi

# Keep the caller's T3 home under privilege escalation; the dispatcher selects
# the active service CLI and its matching libraries instead of root's install.
command=(env "PATH=$PATH" "HOME=$HOME" "T3CODE_HOME=$base" DEBIAN_FRONTEND=noninteractive "${T3_BROWSER_CLI:?}" browser setup)
if [ "$(id -u)" = 0 ]; then
  exec "${command[@]}"
fi
exec sudo -n "${command[@]}"
