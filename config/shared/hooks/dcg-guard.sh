#!/usr/bin/env bash

# Fail closed when the destructive command guard is unavailable or cannot
# complete normally. Hook runners only treat exit status 2 as a hard refusal.

set -u

dcg_bin="$(type -P dcg 2>/dev/null || true)"
if [[ -z $dcg_bin || ! -x $dcg_bin ]]; then
  printf '%s\n' \
    'BLOCKED by dcg-guard.sh: dcg is unavailable; refusing to run an unguarded shell command' \
    >&2
  exit 2
fi

DCG_FAIL_CLOSED=1 "$dcg_bin"
dcg_status=$?

case "$dcg_status" in
0 | 2) exit "$dcg_status" ;;
*)
  printf 'BLOCKED by dcg-guard.sh: dcg failed with status %s; refusing to run an unguarded shell command\n' \
    "$dcg_status" >&2
  exit 2
  ;;
esac
