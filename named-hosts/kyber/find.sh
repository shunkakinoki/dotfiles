#!/usr/bin/env bash
# Reject broad filesystem discovery before it can compete with host services.
set -euo pipefail
native_find="$1"
shift
arguments=("$@")
roots=()
index=0
while [ "$index" -lt "${#arguments[@]}" ]; do
  argument="${arguments[$index]}"
  case "$argument" in
    -H | -L | -P | -O[0-3] | --) ;;
    -D) index=$((index + 1)) ;;
    -*) break ;;
    '(' | '!') break ;;
    *) roots+=("$argument") ;;
  esac
  index=$((index + 1))
done
if [ "${#roots[@]}" -eq 0 ]; then
  roots=(.)
fi

# Only a leading depth bound counts. A token inside -exec or another
# predicate must not accidentally authorize a broad traversal.
bounded=0
if [ "${arguments[$index]:-}" = -maxdepth ]; then
  case "${arguments[$((index + 1))]:-}" in 0 | 1 | 2) bounded=1 ;; esac
fi
depth_options=0
for argument in "${arguments[@]}"; do
  case "$argument" in
    -maxdepth) depth_options=$((depth_options + 1)) ;;
    -files0-from)
      echo "Kyber find: use explicit search roots so their scope can be checked." >&2
      exit 2
      ;;
  esac
done
if [ "$depth_options" -gt 1 ]; then bounded=0; fi
if [ "${#arguments[@]}" -eq 1 ]; then
  case "${arguments[0]}" in --help | --version) exec "$native_find" "$@" ;; esac
fi

if [ "$bounded" -eq 0 ]; then
  for root in "${roots[@]}"; do
    root="$(realpath -m -- "$root")"
    broad=0
    case "$root" in
      / | /home | /root | "$HOME" | "$HOME/.herdr" | "$HOME/.herdr/worktrees" | "$HOME/ghq" | "$HOME/ghq/github.com") broad=1 ;;
      "$HOME/.herdr/worktrees/"*)
        remaining="${root#"$HOME/.herdr/worktrees/"}"
        if [[ "$remaining" != */* ]]; then broad=1; fi
        ;;
    esac
    if [ "$broad" -eq 1 ]; then
      echo "Kyber find: narrow the search to one project or state directory, or put -maxdepth 0, 1, or 2 before the filters." >&2
      exit 2
    fi
  done
fi
exec "$native_find" "$@"
