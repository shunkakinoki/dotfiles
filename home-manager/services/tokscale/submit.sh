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

# tokscale 4.13.0 hardcodes a 15s Cursor HTTP timeout, so `cursor sync` aborts
# while reading the usage CSV (junhoyeo/tokscale#1175). Prefetch into
# cursor-cache so submit's "using cached data" path still has a fresh export.
prefetch_cursor_usage() {
  local creds cache_dir token tmp out first
  creds="${HOME}/.config/tokscale/cursor-credentials.json"
  cache_dir="${HOME}/.config/tokscale/cursor-cache"

  if [ ! -f "$creds" ]; then
    echo "no Cursor credentials, skipping prefetch"
    return 0
  fi

  token="$(jq -r '.accounts[.activeAccountId].sessionToken // empty' "$creds" 2>/dev/null || true)"
  if [ -z "$token" ]; then
    echo "Cursor session token missing, skipping prefetch"
    return 0
  fi

  mkdir -p "$cache_dir"
  tmp="${cache_dir}/.tmp-usage.csv"
  out="${cache_dir}/usage.csv"

  echo "prefetching Cursor usage CSV"
  if ! curl -fsSL --connect-timeout 20 --max-time 180 \
    -A "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36" \
    -H "Accept: */*" \
    -H "Referer: https://www.cursor.com/settings" \
    -H "Cookie: WorkosCursorSessionToken=${token}" \
    -o "$tmp" \
    "https://cursor.com/api/dashboard/export-usage-events-csv?strategy=tokens"; then
    echo "Cursor usage prefetch failed; submit will use cached data if any" >&2
    rm -f "$tmp"
    return 0
  fi

  IFS= read -r first <"$tmp" || true
  if [[ "$first" != Date,* ]]; then
    echo "Cursor usage prefetch returned non-CSV; keeping previous cache" >&2
    rm -f "$tmp"
    return 0
  fi

  chmod 600 "$tmp"
  mv -f "$tmp" "$out"
  echo "wrote ${out}"
}

prefetch_cursor_usage

# stdin from /dev/null keeps submit non-interactive (skips the "star the repo"
# prompt seen on a TTY).
#
# Wrap with `timeout`: Kyber's cold scan reads multi-gigabyte client histories
# and Tokscale's source-message cache while the host is under sustained disk
# pressure. Keep a finite ceiling so a genuinely wedged scan cannot overlap the
# next three-hour timer slot, but allow the observed cold scan more than the
# previous four-minute budget.
timeout 900 bun "$TOKSCALE_BIN" submit </dev/null
