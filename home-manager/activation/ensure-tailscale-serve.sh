#!/usr/bin/env bash
# Publish a local HTTP port over Tailscale Serve (tailnet-only HTTPS).
#
# Usage: ensure-tailscale-serve.sh <https-port> <local-port> [<https-port> <local-port>...]
#
# Services that need the serve root must use distinct HTTPS ports rather than
# path prefixes. The helper reconciles exact HTTPS-port-to-local-port mappings
# without disturbing other routes on the same node.
#
# `tailscale serve` persists in tailscaled state, so this is a no-op on every
# activation after the first.
set -euo pipefail

: "${1:?https port required}"
: "${2:?local port required}"
if [ $(($# % 2)) -ne 0 ]; then
  echo "serve routes require HTTPS/local port pairs" >&2
  exit 2
fi

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
  echo "tailscale not found; skipping serve setup" >&2
  exit 0
fi

# Not logged in / daemon down: leave the config alone rather than erroring the
# whole activation.
if ! "$TS" status >/dev/null 2>&1; then
  echo "tailscale not running; skipping serve setup" >&2
  exit 0
fi

SERVE_STATUS="$("$TS" serve status 2>/dev/null || true)"

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
  echo "no sudo/doas available; skipping serve setup" >&2
  exit 0
fi

ensure_route() {
  local https_port="$1"
  local local_port="$2"
  local target="http://127.0.0.1:${local_port}"

  if printf '%s\n' "$SERVE_STATUS" | awk -v port="$https_port" -v target="$target" '
    /^https:\/\// {
      if (port == "443") {
        active = ($0 !~ /:[0-9]+ \(tailnet only\)$/)
      } else {
        active = ($0 ~ (":" port " \\(tailnet only\\)$"))
      }
      next
    }
    active && index($0, "proxy " target) { found = 1 }
    END { exit found ? 0 : 1 }
  '; then
    return 0
  fi

  echo "Publishing ${target} over Tailscale Serve on :${https_port}..."
  if [ -n "$SUDO_CMD" ]; then
    "$SUDO_CMD" "$TS" serve --yes --bg --https="${https_port}" "${target}"
  else
    "$TS" serve --yes --bg --https="${https_port}" "${target}"
  fi
}

while [ "$#" -gt 0 ]; do
  ensure_route "$1" "$2"
  shift 2
done
