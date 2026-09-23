#!/usr/bin/env bash
# Plugin builds and model-catalog captures are multi-GB mkdtemp directories
# that a stop ending in SIGKILL leaves behind on the RAM-backed runtime tmpfs,
# where the next startup then fails with ENOSPC. ExecStartPre runs only after
# the previous instance's cgroup is empty and TMPDIR is private to this unit,
# so every match is orphaned.
mkdir -p "${TMPDIR:?}"
find "$TMPDIR" -mindepth 1 -maxdepth 1 -type d \
  \( -name 'openclaw-plugin-build-*' -o -name 'openclaw-model-catalog-*' \) \
  -exec rm -rf {} +
