#!/usr/bin/env bash
# Apply per-device hidutil UserKeyMapping entries.
#
# Each invocation of `apply_mapping` takes two JSON strings:
#   1. match   - selector passed to `hidutil --matching` (e.g. {"VendorID":...})
#   2. mapping - mapping payload passed to `hidutil --set`  (e.g. {"UserKeyMapping":[]})
#
# The actual list of mappings is generated from Nix data and rendered into the
# call sites below by `pkgs.replaceVars`.
set -euo pipefail

hidutil_bin="@hidutilBin@"

apply_mapping() {
  local match="$1"
  local mapping="$2"
  local _

  for _ in 1 2 3 4 5; do
    if "$hidutil_bin" property --matching "$match" --set "$mapping" >/dev/null 2>&1; then
      return 0
    fi
    sleep 1
  done
  return 0
}

@perDeviceCalls@
