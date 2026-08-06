#!/usr/bin/env bash
# Periodic CAAM vault sync with peers in the sync pool.
set -euo pipefail

CAAM="${CAAM:-$HOME/.local/bin/caam}"

if [[ ! -x $CAAM ]]; then
  echo "caam not found at $CAAM; skipping sync" >&2
  exit 0
fi

export PATH="$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin${PATH:+:$PATH}"

# Prefer the user agent when available so SSH to kyber/matic works headlessly.
if [[ -z ${SSH_AUTH_SOCK:-} ]]; then
  for sock in \
    "$HOME/.ssh/agent.sock" \
    /run/user/"$(id -u)"/ssh-agent.socket \
    /run/user/"$(id -u)"/keyring/ssh; do
    if [[ -S $sock ]]; then
      export SSH_AUTH_SOCK="$sock"
      break
    fi
  done
fi

exec "$CAAM" sync
