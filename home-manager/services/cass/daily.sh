#!/usr/bin/env bash
set -euo pipefail

CASS="$HOME/.local/bin/cass"
if [ -n "${CASS_DAILY_TIMEOUT_BIN:-}" ]; then
  TIMEOUT_BIN="$CASS_DAILY_TIMEOUT_BIN"
elif command -v timeout >/dev/null 2>&1; then
  TIMEOUT_BIN="$(command -v timeout)"
else
  echo "cass daily: timeout binary not found; refusing to run unbounded" >&2
  exit 1
fi
SYNC_TIMEOUT="${CASS_DAILY_SYNC_TIMEOUT:-10m}"
ANALYTICS_TIMEOUT="${CASS_DAILY_ANALYTICS_TIMEOUT:-15m}"

if [ ! -x "$CASS" ]; then
  echo "cass binary not found at $CASS"
  exit 1
fi

echo "$(date): starting cass daily sync + analytics"

# Sync remote sources (ignore failures for unreachable hosts)
if ! "$TIMEOUT_BIN" --signal=TERM --kill-after=30s "$SYNC_TIMEOUT" \
  "$CASS" sources sync; then
  echo "$(date): cass source sync failed or timed out; continuing to analytics" >&2
fi

# Rebuild analytics rollup tables, but never allow the daily job to wedge the
# machine indefinitely on a large archive.
if ! "$TIMEOUT_BIN" --signal=TERM --kill-after=30s "$ANALYTICS_TIMEOUT" \
  "$CASS" analytics rebuild --since -1d; then
  echo "$(date): cass analytics rebuild failed or timed out" >&2
  exit 1
fi

echo "$(date): cass daily sync + analytics complete"
