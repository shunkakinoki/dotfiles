#!/usr/bin/env bash
set -euo pipefail

source_name="${1:-${SMARTD_DEVICE:-kyber-host-health}}"
message="${2:-${SMARTD_MESSAGE:-Kyber host reliability alert}}"
alert="${source_name}: ${message}"

# The operator acknowledged this disk's low endurance and muted that warning.
# Device failures and unreadable SMART data use different sources and still alert.
if [ "$source_name" = "disk-wear-sda" ]; then
  logger --priority daemon.info --tag kyber-host-health -- "$alert (notification suppressed)"
else
  logger --priority daemon.alert --tag kyber-host-health -- "$alert"
fi
