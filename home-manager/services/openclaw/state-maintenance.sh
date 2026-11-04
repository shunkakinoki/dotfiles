#!/usr/bin/env bash
# Reclaim free pages only while the gateway is already offline. CLI snapshot
# budgets scale with file size, so an unbounded openclaw.sqlite eventually
# prevents state-backed commands, including orchestration paging, from working.
#
# Automatic compaction must not interrupt the scheduler and its fleet refills.
# This only reclaims free pages; keeping writers bounded is a config concern.

STATE_DB="${HOME}/.openclaw/state/openclaw.sqlite"
SNAPSHOT_REPO="${HOME}/Backups/openclaw-sqlite"
OPENCLAW="${HOME}/.bun/bin/openclaw"
COMPACT_THRESHOLD_BYTES=134217728

exit_status=0

log() {
  printf '%s state-maintenance: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*"
}

if [ ! -x "${OPENCLAW}" ]; then
  log "openclaw binary missing at ${OPENCLAW}"
  exit 1
fi

# Kyber's host user manager refuses the newer nixpkgs systemctl on its private
# socket, so only the host client can reach it.
SYSTEMCTL=/usr/bin/systemctl

# Compaction needs the state ownership lock the running gateway holds. With the
# gateway's state unknown, the snapshot would copy the whole database onto the
# shared disk only for compaction to be refused.
gateway_state=$("${SYSTEMCTL}" --user is-active openclaw-gateway.service || true)
case "${gateway_state}" in
active)
  log "gateway active; skipping offline maintenance"
  exit 0
  ;;
inactive | failed) ;;
*)
  log "cannot read gateway state (${gateway_state:-no answer}); skipping"
  exit 1
  ;;
esac

size_bytes=0
if [ -f "${STATE_DB}" ]; then
  size_bytes=$(stat -c %s "${STATE_DB}")
fi
log "state db is ${size_bytes} bytes"

if [ "${size_bytes}" -ge "${COMPACT_THRESHOLD_BYTES}" ]; then
  # `backup sqlite create` refuses a repository whose ancestor another user
  # could replace.
  mkdir -p "${SNAPSHOT_REPO}"
  chmod 700 "$(dirname "${SNAPSHOT_REPO}")" "${SNAPSHOT_REPO}"
  if "${OPENCLAW}" backup sqlite create --global --repository "${SNAPSHOT_REPO}"; then
    if ! "${OPENCLAW}" doctor --state-sqlite compact --json; then
      log "state compaction failed"
      exit_status=1
    fi
  else
    log "snapshot failed; skipping compaction"
    exit_status=1
  fi
fi

exit "${exit_status}"
