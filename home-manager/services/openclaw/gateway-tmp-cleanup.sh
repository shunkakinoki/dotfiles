#!/usr/bin/env bash
# Plugin builds and model-catalog captures are multi-GB mkdtemp directories
# that OpenClaw abandons both on SIGKILL and while the gateway keeps running.
# ExecStartPre runs without an age argument: the previous instance's cgroup is
# empty and TMPDIR is private to this unit, so every match is orphaned. The
# periodic run passes an idle age in minutes and only removes trees with no
# entry modified within it, because a live build keeps writing below the
# top-level directory without touching its mtime.
umask 077
min_idle_minutes="${1:-}"
# A find error inside the idle probe yields empty output, which would read as
# idle and delete a live tree.
if [ -n "$min_idle_minutes" ] && ! [[ $min_idle_minutes =~ ^[0-9]+$ ]]; then
  echo "invalid idle minutes: $min_idle_minutes" >&2
  exit 2
fi
mkdir -p "${TMPDIR:?}"
chmod 700 "$TMPDIR"
find "$TMPDIR" -mindepth 1 -maxdepth 1 -type d \
  \( -name 'openclaw-plugin-build-*' -o -name 'openclaw-model-catalog-*' \) \
  -print0 |
  while IFS= read -r -d '' dir; do
    if [ -n "$min_idle_minutes" ] &&
      [ -n "$(find "$dir" -mmin "-$min_idle_minutes" -print -quit)" ]; then
      continue
    fi
    rm -rf "$dir"
  done
