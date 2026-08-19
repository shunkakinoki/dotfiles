#!/usr/bin/env bash
# Submit local usage data to Tokscale. Runs on a 3h schedule on all machines.
set -euo pipefail

# Workaround for junhoyeo/tokscale#1002: the Rust binary's TLS stack cannot
# locate NixOS CA certs without an explicit pointer.
export SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt

# tokscale is installed as a bun global (see modules/npm-globals). Invoke its
# entrypoint through bun so we do not depend on `node` being on PATH (bin.js
# uses an `env node` shebang).
TOKSCALE_BIN="${HOME}/.bun/install/global/node_modules/tokscale/bin.js"
if [ ! -f "$TOKSCALE_BIN" ]; then
  echo "tokscale not installed at ${TOKSCALE_BIN}, skipping"
  exit 0
fi

# stdin from /dev/null keeps submit non-interactive (skips the "star the repo"
# prompt seen on a TTY).
#
# Wrap with `timeout`: the scan intermittently hangs on Kyber (100+ parked
# threads, ~0% CPU, no progress - e.g. walking the 34k+ entry
# ~/.config/Code/logs tree). A hard cap makes a wedged submit self-terminate
# instead of pinning the oneshot thread until the next tick. 240s covers a cold
# scan of all active clients (codex 2.1G, opencode 1.2G DB); adjust if the 3h
# cadence drifts.
timeout 240 bun "$TOKSCALE_BIN" submit </dev/null
