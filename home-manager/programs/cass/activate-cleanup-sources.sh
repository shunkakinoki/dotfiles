#!/usr/bin/env bash
# Drop a previously hydrated sources.toml before nix linkGeneration runs.
#
# hydrate.sh writes this file at activation time, so it is a writable artifact
# rather than a store symlink. Home Manager refuses to clobber it and aborts the
# generation, so it has to go first.
set -euo pipefail

SOURCES="${1:?sources.toml path required}"

if [ -f "$SOURCES" ]; then
  rm -f "$SOURCES"
fi
