#!/usr/bin/env bash
set -euo pipefail

# Shell hooks run before an executor command. A busy or failed history store
# must not hold the shell; interactive search, sync and the daemon keep their
# own timeouts. GNU timeout also bounds a client that ignores TERM.
if [ "$#" -ge 2 ] && [ "$1" = history ] &&
  { [ "$2" = start ] || [ "$2" = end ]; }; then
  exec @timeout@ --kill-after=1s 2s @atuin@ "$@"
fi
exec @atuin@ "$@"
