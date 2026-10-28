#!/usr/bin/env bash
set -euo pipefail

export LC_ALL=C
original=${SSH_ORIGINAL_COMMAND-}

if [[ $original =~ ^beads-linear-complete[[:blank:]]+([A-Za-z0-9][A-Za-z0-9._-]*/[A-Za-z0-9][A-Za-z0-9._-]*)[[:blank:]]+([A-Za-z0-9][A-Za-z0-9._-]*)$ ]]; then
  exec "${0%/*}/beads-linear-complete" "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}"
fi

printf '%s\n' 'This key permits only managed Beads completion.' >&2
exit 126
