#!/usr/bin/env bash

# Keep captive portal connections alive by periodically hitting neverssl.com

set -euo pipefail

# Silently ping neverssl.com - ignore failures (network may be unavailable)
if curl -fsS --max-time 10 http://neverssl.com >/dev/null 2>&1; then
  echo "$(date): OK"
else
  echo "$(date): FAIL" >&2
fi

# macOS-specific: Open captive portal for Starbucks WiFi if connectivity is lost
if [[ $OSTYPE == "darwin"* ]]; then
  SSID=$(networksetup -getairportnetwork en0 2>/dev/null | awk -F": " '{print $2}' || echo "")

  # Check for Starbucks networks (e.g., at_STARBUCKS_Wi2)
  if [[ $SSID == *"STARBUCKS"* ]]; then
    if ! ping -c 1 -W 2 1.1.1.1 >/dev/null 2>&1; then
      open "http://captive.apple.com" 2>/dev/null || true
    fi
  fi
fi
