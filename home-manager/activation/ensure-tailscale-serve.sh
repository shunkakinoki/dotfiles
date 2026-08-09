#!/usr/bin/env bash
# Publish a local HTTP port over Tailscale Serve (tailnet-only HTTPS).
#
# Usage: ensure-tailscale-serve.sh <https-port> <local-port>
#
# The T3 client discovers a remote environment via
# https://<magicdns-name>[:<https-port>]/.well-known/t3/environment, so the
# backend has to be reachable over HTTPS and the well-known path has to sit at
# the serve root. A host already serving something else at :443 (kyber serves
# openclaw there) therefore needs T3 on its own HTTPS port rather than a path
# prefix.
#
# `tailscale serve` persists in tailscaled state, so this is a no-op on every
# activation after the first.
set -euo pipefail

HTTPS_PORT="${1:?https port required}"
LOCAL_PORT="${2:?local port required}"
TARGET="http://127.0.0.1:${LOCAL_PORT}"

if ! command -v tailscale >/dev/null 2>&1; then
  echo "tailscale not on PATH; skipping serve setup for :${HTTPS_PORT}" >&2
  exit 0
fi

# Not logged in / daemon down: leave the config alone rather than erroring the
# whole activation.
if ! tailscale status >/dev/null 2>&1; then
  echo "tailscale not running; skipping serve setup for :${HTTPS_PORT}" >&2
  exit 0
fi

if tailscale serve status 2>/dev/null | grep -qF "${TARGET}"; then
  exit 0
fi

SUDO_CMD=""
if [ "$(id -u)" -ne 0 ]; then
  if command -v sudo >/dev/null 2>&1; then
    SUDO_CMD="sudo"
  elif [ -x /run/wrappers/bin/sudo ]; then
    SUDO_CMD="/run/wrappers/bin/sudo"
  elif command -v doas >/dev/null 2>&1; then
    SUDO_CMD="doas"
  fi
fi

echo "Publishing ${TARGET} over Tailscale Serve on :${HTTPS_PORT}..."
if [ -n "$SUDO_CMD" ]; then
  "$SUDO_CMD" tailscale serve --bg --https="${HTTPS_PORT}" "${TARGET}"
else
  tailscale serve --bg --https="${HTTPS_PORT}" "${TARGET}"
fi
