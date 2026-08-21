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
# scan Tokscale's remaining default-submit clients as a group. Crush, Trae,
# Warp, and 9Router are deliberately absent because Tokscale itself excludes
# them from unfiltered submissions.
#
# Interactive submit starts a detached full-history TUI-cache scan after a
# successful upload. On systemd hosts, run each phase in its own transient
# service so KillMode=control-group removes that cache warmer before the next
# phase starts. Other platforms retain the normal direct invocation.
run_submit_phase() {
  local phase="$1"
  shift

  if command -v systemd-run >/dev/null 2>&1 &&
    command -v systemctl >/dev/null 2>&1 &&
    systemctl --user show-environment >/dev/null 2>&1; then
    systemd-run --user --wait --collect --pipe --quiet \
      --unit="tokscale-submit-${BASHPID}-${phase}" \
      --property=KillMode=control-group \
      --setenv="HOME=$HOME" \
      --setenv="PATH=$PATH" \
      --setenv="SSL_CERT_FILE=$SSL_CERT_FILE" \
      timeout 900 bun "$TOKSCALE_BIN" --no-spinner submit "$@" </dev/null
  else
    timeout 900 bun "$TOKSCALE_BIN" --no-spinner submit "$@" </dev/null
  fi
}

remaining_clients=(
  amp
  antigravity
  antigravity-cli
  augment
  claude
  cline
  codebuddy
  codebuff
  codex
  commandcode
  copilot
  cursor
  devin-cli
  devin-desktop
  droid
  freebuff
  gemini
  gjc
  goose
  grok
  hermes
  jcode
  junie
  kilocode
  kilo
  kimchi
  kimi
  kiro
  micode
  mux
  openclaw
  opencodereview
  pi
  prime-agent
  qwen
  reasonix
  roocode
  senpi
  synthetic
  workbuddy
  zcode
  zed
)
remaining_client_csv=$(
  IFS=,
  echo "${remaining_clients[*]}"
)

# Each phase gets a bounded fifteen-minute cold-start window. Run both phases
# even if the first fails, then propagate a non-zero result so the scheduler
# records partial failure without leaving detached scanners behind.
submit_status=0
run_submit_phase opencode --client opencode || submit_status=$?
run_submit_phase remaining --client "$remaining_client_csv" || submit_status=$?
exit "$submit_status"
