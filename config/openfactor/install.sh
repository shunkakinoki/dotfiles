#!/usr/bin/env bash
# Register OpenFactor's host-scoped orchestration hooks when the OpenFactor CLI
# is installed. The CLI owns harness adapters and receipts; this wrapper only
# provides the durable Home Manager activation boundary.
# Hook registration is optional, so a missing, outdated, or failing CLI warns
# instead of aborting the rest of Home Manager activation.
set -euo pipefail

OPENFACTOR_BIN="${OPENFACTOR_BIN:-}"
if [[ -z $OPENFACTOR_BIN ]]; then
  OPENFACTOR_BIN="$(PATH="$HOME/.local/bin:${PATH:-}" command -v openfactor 2>/dev/null || true)"
fi

if [[ -z $OPENFACTOR_BIN ]]; then
  echo "OpenFactor CLI not found; skipping orchestration hook registration" >&2
  exit 0
fi

if [[ ! -x $OPENFACTOR_BIN ]]; then
  echo "warning: OpenFactor CLI is not executable: $OPENFACTOR_BIN; skipping orchestration hook registration" >&2
  exit 0
fi

if ! "$OPENFACTOR_BIN" hooks install --scope host --json; then
  echo "warning: OpenFactor hook registration failed; continuing activation" >&2
fi
