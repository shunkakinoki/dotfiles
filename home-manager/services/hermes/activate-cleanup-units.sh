#!/usr/bin/env bash
# Drop writable copies of the hermes units before nix linkGeneration runs.
#
# #2317 replaced read-only store symlinks with writable copies so the units
# could be edited in place. Home Manager will not overwrite a real file, so any
# leftover copy blocks the generation. A symlink is already store-managed and
# must be left alone -- only regular files are removed.
set -euo pipefail

UNIT_DIR="${1:?systemd user unit directory required}"
shift

for name in "$@"; do
  unit="${UNIT_DIR}/${name}"
  if [ -f "$unit" ] && [ ! -L "$unit" ]; then
    rm -f "$unit"
  fi
done
