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
# Kyber's OpenCode database is large enough that scanning it alongside every
# other client creates heavy random-I/O contention. Submit it separately, then
# scan the remaining active clients as a group. Each phase gets a bounded
# fifteen-minute cold-start window; observed warm runs complete in 30s and
# 158s respectively. Run both phases even if the first fails, then propagate a
# non-zero result so systemd still records partial failure.
submit_status=0
timeout 900 bun "$TOKSCALE_BIN" submit --client opencode </dev/null || submit_status=$?
timeout 900 bun "$TOKSCALE_BIN" submit \
  --client antigravity-cli,claude,codex,droid,grok,hermes,openclaw \
  </dev/null || submit_status=$?
exit "$submit_status"
