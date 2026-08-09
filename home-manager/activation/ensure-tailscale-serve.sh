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

# Home Manager activation runs with a minimal PATH, so `command -v` alone finds
# nothing. Search where each host actually keeps it, and prefer the installed
# CLI over a nix one so it always matches the running daemon.
TS=""
for candidate in \
  "$(command -v tailscale 2>/dev/null || true)" \
  "${HOME}/.nix-profile/bin/tailscale" \
  "/etc/profiles/per-user/$(id -un)/bin/tailscale" \
  /run/current-system/sw/bin/tailscale \
  /usr/bin/tailscale \
  /usr/local/bin/tailscale; do
  if [ -n "$candidate" ] && [ -x "$candidate" ]; then
    TS="$candidate"
    break
  fi
done

if [ -z "$TS" ]; then
  echo "tailscale not found; skipping serve setup for :${HTTPS_PORT}" >&2
  exit 0
fi

# Not logged in / daemon down: leave the config alone rather than erroring the
# whole activation.
if ! "$TS" status >/dev/null 2>&1; then
  echo "tailscale not running; skipping serve setup for :${HTTPS_PORT}" >&2
  exit 0
fi

if "$TS" serve status 2>/dev/null | grep -qF "${TARGET}"; then
  exit 0
fi

# Same minimal-PATH problem as above: fall back to absolute paths.
SUDO_CMD=""
if [ "$(id -u)" -ne 0 ]; then
  for candidate in \
    "$(command -v sudo 2>/dev/null || true)" \
    /run/wrappers/bin/sudo \
    /usr/bin/sudo \
    "$(command -v doas 2>/dev/null || true)" \
    /usr/bin/doas; do
    if [ -n "$candidate" ] && [ -x "$candidate" ]; then
      SUDO_CMD="$candidate"
      break
    fi
  done
fi

# `tailscale serve` needs root unless the user is a tailscale operator. Skipping
# beats aborting the whole switch over an endpoint that can be set up later.
if [ -z "$SUDO_CMD" ] && [ "$(id -u)" -ne 0 ]; then
  echo "no sudo/doas available; skipping serve setup for :${HTTPS_PORT}" >&2
  exit 0
fi

echo "Publishing ${TARGET} over Tailscale Serve on :${HTTPS_PORT}..."
if [ -n "$SUDO_CMD" ]; then
  "$SUDO_CMD" "$TS" serve --bg --https="${HTTPS_PORT}" "${TARGET}"
else
  "$TS" serve --bg --https="${HTTPS_PORT}" "${TARGET}"
fi
