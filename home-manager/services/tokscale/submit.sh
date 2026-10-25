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

# Native sync handles ordinary increments. The managed helper bootstraps missing
# or over-limit caches through verified date chunks without changing Tokscale.
CURSOR_SYNC_SCRIPT="${1:-$(dirname "${BASH_SOURCE[0]}")/sync-cursor.py}"
cursor_status=0
if timeout 900 python3 "$CURSOR_SYNC_SCRIPT" "$TOKSCALE_BIN" </dev/null; then
  :
else
  cursor_status=$?
  echo "Cursor sync incomplete; uploading available data before reporting failure" >&2
fi

# Antigravity IDE usage is pull-based: `submit` only reads the local
# antigravity-cache, which stays empty unless this sync runs while an
# Antigravity language server is up. It exits 0 with an empty cache when the IDE
# is closed or absent, so it never blocks the submit below.
if ! timeout 300 bun "$TOKSCALE_BIN" antigravity sync </dev/null; then
  echo "Antigravity sync failed; submit will use the existing cache" >&2
fi

# stdin from /dev/null keeps submit non-interactive (skips the "star the repo"
# prompt seen on a TTY).
#
# Wrap with `timeout`: Kyber's cold scan reads multi-gigabyte client histories
# and Tokscale's source-message cache while the host is under sustained disk
# pressure. Keep a finite ceiling so a genuinely wedged scan cannot overlap the
# next three-hour timer slot, but allow the observed cold scan more than the
# previous four-minute budget.
timeout 900 bun "$TOKSCALE_BIN" --no-spinner submit </dev/null
exit "$cursor_status"
