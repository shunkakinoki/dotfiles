#!/usr/bin/env bash
# shellcheck disable=SC2329
# Bound the shared state database. CLI commands open a read-only snapshot whose
# time budget scales with file size, so an unbounded openclaw.sqlite eventually
# makes every state-backed command (including `openclaw message send`, which the
# orchestrator pages through) fail before it can do anything.
#
# The product's own pruner only removes task rows whose `cleanup_after` is
# already due, and that column is stamped at a fixed created_at + 7d with no
# config knob, so this job cannot tighten task retention. It stamps, prunes and
# reclaims free pages; keeping the writers themselves bounded is a config
# concern.

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
  exit_status=1
fi

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
