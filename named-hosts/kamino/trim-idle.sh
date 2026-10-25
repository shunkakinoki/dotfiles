#!/usr/bin/env bash
# ExecCondition: skip this maintenance opportunity when the worker disk is busy.
set -euo pipefail
pressure="${1:-/proc/pressure/io}"
awk '
  $1 == "some" {
    for (i = 2; i <= NF; i++) {
      if ($i ~ /^avg60=[0-9]+([.][0-9]+)?$/) {
        split($i, field, "=")
        found = 1
        busy = field[2] >= 1
      }
    }
  }
  END { exit (!found || busy) }
' "$pressure"
