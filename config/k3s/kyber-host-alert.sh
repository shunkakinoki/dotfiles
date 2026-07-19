#!/usr/bin/env bash
set -euo pipefail

source_name="${1:-${SMARTD_DEVICE:-kyber-host-health}}"
message="${2:-${SMARTD_MESSAGE:-Kyber host reliability alert}}"
alert="${source_name}: ${message}"

logger --priority daemon.alert --tag kyber-host-health -- "$alert"
printf 'KYBER ALERT: %s\n' "$alert" | wall --nobanner || true
