#!/usr/bin/env bash

# Keep captive portal connections alive by periodically hitting neverssl.com

set -euo pipefail

# Silently ping neverssl.com - ignore failures (network may be unavailable)
curl -fsS --max-time 10 http://neverssl.com >/dev/null 2>&1 || true
