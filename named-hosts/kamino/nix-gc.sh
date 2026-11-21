#!/usr/bin/env bash
# Prune stale t3-rollout gcroots and run bounded Nix garbage collection on Kamino.
set -euo pipefail

state_home="${XDG_STATE_HOME:-$HOME/.local/state}"
rollout_dir="${state_home}/t3-rollout"
rollout_age_days="${KAMINO_NIX_GC_ROLLOUT_AGE_DAYS:-3}"
if [[ ! "$rollout_age_days" =~ ^[1-9][0-9]*$ ]]; then
  echo "Invalid KAMINO_NIX_GC_ROLLOUT_AGE_DAYS: $rollout_age_days" >&2
  exit 1
fi
gc_age="${KAMINO_NIX_GC_DELETE_OLDER_THAN:-3d}"
rollout_minutes=$((rollout_age_days * 1440))

if [ -d "$rollout_dir" ]; then
  while IFS= read -r -d '' entry; do
    if [ -d "$entry" ] && [ ! -L "$entry" ]; then
      recent=$(find "$entry" -mmin "-$rollout_minutes" -print -quit 2>/dev/null) || continue
      [ -n "$recent" ] && continue
    fi
    rm -rf -- "$entry"
  done < <(find "$rollout_dir" -mindepth 1 -maxdepth 1 -mmin +"$rollout_minutes" -print0)
fi

if ! command -v nix-collect-garbage >/dev/null 2>&1; then
  echo "nix-collect-garbage not found on PATH; skipping Nix GC." >&2
  exit 0
fi

exec nix-collect-garbage --delete-older-than "$gc_age"
