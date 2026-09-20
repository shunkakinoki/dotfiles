#!/usr/bin/env bash
# Bound the shared state database. CLI commands open a read-only snapshot whose
# time budget scales with file size, so an unbounded openclaw.sqlite eventually
# makes every state-backed command (including `openclaw message send`, which the
# orchestrator pages through) fail before it can do anything.

STATE_DB="${HOME}/.openclaw/state/openclaw.sqlite"
SNAPSHOT_REPO="${HOME}/Backups/openclaw-sqlite"
OPENCLAW="${HOME}/.bun/bin/openclaw"
COMPACT_THRESHOLD_BYTES=134217728

log() {
  printf '%s state-maintenance: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*"
}

if [ ! -x "${OPENCLAW}" ]; then
  log "openclaw binary missing at ${OPENCLAW}"
  exit 0
fi

gateway_was_active=0
if systemctl --user is-active --quiet openclaw-gateway.service; then
  gateway_was_active=1
fi

restore_gateway() {
  if [ "${gateway_was_active}" -eq 1 ]; then
    systemctl --user start openclaw-gateway.service || log "gateway restart failed"
  fi
}
trap restore_gateway EXIT

# Both the task pruner and the sqlite compactor need the state ownership lock,
# which the running gateway holds.
if [ "${gateway_was_active}" -eq 1 ]; then
  systemctl --user stop openclaw-gateway.service
fi

if ! "${OPENCLAW}" tasks maintenance --apply; then
  log "tasks maintenance failed"
fi

size_bytes=0
if [ -f "${STATE_DB}" ]; then
  size_bytes=$(stat -c %s "${STATE_DB}")
fi
log "state db is ${size_bytes} bytes"

if [ "${size_bytes}" -ge "${COMPACT_THRESHOLD_BYTES}" ]; then
  mkdir -p "${SNAPSHOT_REPO}"
  if "${OPENCLAW}" backup sqlite create --global --repository "${SNAPSHOT_REPO}"; then
    if ! "${OPENCLAW}" doctor --state-sqlite compact --json; then
      log "state compaction failed"
    fi
  else
    log "snapshot failed; skipping compaction"
  fi
fi
