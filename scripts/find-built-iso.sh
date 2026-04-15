#!/usr/bin/env bash

set -euo pipefail

result_path="${1:-./result}"

if [ ! -e "$result_path" ]; then
  exit 1
fi

print_iso_if_file() {
  local candidate_path="$1"

  case "$candidate_path" in
  *.iso)
    if [ -f "$candidate_path" ]; then
      printf '%s\n' "$candidate_path"
      exit 0
    fi
    ;;
  esac
}

print_iso_if_file "$result_path"

resolved_path=""
if command -v readlink >/dev/null 2>&1; then
  resolved_path="$(readlink -f "$result_path" 2>/dev/null || true)"
fi
if [ -z "$resolved_path" ] && command -v realpath >/dev/null 2>&1; then
  resolved_path="$(realpath "$result_path" 2>/dev/null || true)"
fi

print_iso_if_file "$resolved_path"

iso_path="$(find -L "$result_path" -type f -name '*.iso' | sort | head -n 1)"
if [ -n "$iso_path" ]; then
  printf '%s\n' "$iso_path"
  exit 0
fi

exit 1
