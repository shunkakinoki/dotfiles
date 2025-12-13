#!/usr/bin/env bash

set -euo pipefail

mock_bin_setup() {
  MOCK_BIN="$(mktemp -d)"
  MOCK_LOG="$MOCK_BIN/mock.log"
  : >"$MOCK_LOG"

  MOCK_ORIGINAL_PATH="${PATH:-}"
  export MOCK_BIN MOCK_LOG MOCK_ORIGINAL_PATH
  export PATH="$MOCK_BIN:$MOCK_ORIGINAL_PATH"

  local cmd
  for cmd in "$@"; do
    cat >"$MOCK_BIN/$cmd" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
: "${MOCK_LOG:?MOCK_LOG must be set}"
printf '%s\n' "$0 $*" >>"$MOCK_LOG"
exit 0
EOF
    chmod +x "$MOCK_BIN/$cmd"
  done
}

mock_bin_cleanup() {
  if [[ -n ${MOCK_ORIGINAL_PATH:-} ]]; then
    export PATH="$MOCK_ORIGINAL_PATH"
  fi
  if [[ -n ${MOCK_BIN:-} ]]; then
    rm -rf "$MOCK_BIN"
  fi
  unset MOCK_BIN MOCK_LOG MOCK_ORIGINAL_PATH
}
