#!/usr/bin/env bash

# Keep captive portal connections alive by periodically hitting neverssl.com

set -euo pipefail

# Silently ping neverssl.com - ignore failures (network may be unavailable)
if curl -fsS --max-time 10 http://neverssl.com >/dev/null 2>&1; then
  echo "$(date): OK"
else
  echo "$(date): FAIL" >&2
fi

# macOS-specific: Restart WiFi to trigger captive portal popup when connectivity is lost
if [[ $OSTYPE == "darwin"* ]]; then
  SSID=$(networksetup -getairportnetwork en0 2>/dev/null | awk -F": " '{print $2}' || echo "")

  # Check for Starbucks or Komeda networks
  if [[ $SSID == *"STARBUCKS"* ]] || [[ $SSID == *"Komeda_Wi-Fi"* ]]; then
    if ! ping -c 1 -W 2 1.1.1.1 >/dev/null 2>&1; then
      # Restart WiFi to trigger macOS captive portal popup
      networksetup -setairportpower en0 off
      sleep 3
      networksetup -setairportpower en0 on
    fi
  fi
fi
