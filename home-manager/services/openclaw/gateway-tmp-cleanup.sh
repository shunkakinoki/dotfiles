#!/usr/bin/env bash
# Plugin builds and model-catalog captures are multi-GB mkdtemp directories
# that a stop ending in SIGKILL can leave behind. ExecStartPre runs only after
# the previous instance's cgroup is empty and TMPDIR is private to this unit,
# so every match is orphaned.
umask 077
mkdir -p "${TMPDIR:?}"
chmod 700 "$TMPDIR"
find "$TMPDIR" -mindepth 1 -maxdepth 1 -type d \
  \( -name 'openclaw-plugin-build-*' -o -name 'openclaw-model-catalog-*' \) \
  -exec rm -rf {} +
