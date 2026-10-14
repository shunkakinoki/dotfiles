#!/usr/bin/env bash
# Install the published OpenFactor CLI and register its host-scoped hooks. The
# CLI owns harness adapters and receipts; this wrapper only provides the
# durable Home Manager activation boundary.
# Hook registration is optional, so an unreachable release, outdated, or
# failing CLI warns instead of aborting the rest of Home Manager activation.
set -euo pipefail

# Activation runs with a minimal PATH; the release installer needs these tools.
if [[ -n ${OPENFACTOR_INSTALL_PATH:-} ]]; then
  PATH="$OPENFACTOR_INSTALL_PATH:${PATH:-}"
fi

OPENFACTOR_RELEASE_ROOT="${OPENFACTOR_RELEASE_ROOT:-https://assets.openfactor.ai/cli/releases}"
managed_bin="$HOME/.local/bin/openfactor"

OPENFACTOR_BIN="${OPENFACTOR_BIN:-}"
if [[ -z $OPENFACTOR_BIN ]]; then
  OPENFACTOR_BIN="$(PATH="$HOME/.local/bin:${PATH:-}" command -v openfactor 2>/dev/null || true)"
fi

if [[ -z $OPENFACTOR_BIN ]]; then
  installer="$(mktemp)"
  if curl -fsSL --connect-timeout 10 --max-time 60 "$OPENFACTOR_RELEASE_ROOT/install.sh" -o "$installer" &&
    CLI_RELEASE_ROOT="$OPENFACTOR_RELEASE_ROOT" CLI_INSTALL_DIR="$HOME/.local/bin" sh "$installer" openfactor >&2; then
    OPENFACTOR_BIN="$managed_bin"
  else
    echo "warning: OpenFactor CLI install failed; skipping orchestration hook registration" >&2
  fi
  rm -f "$installer"
elif [[ $OPENFACTOR_BIN == "$managed_bin" ]]; then
  # The CLI's own upgrade keeps the release current and is a no-op when it is.
  if ! "$OPENFACTOR_BIN" upgrade >&2; then
    echo "warning: OpenFactor CLI upgrade failed; registering hooks with the installed release" >&2
  fi
fi

if [[ -z $OPENFACTOR_BIN ]]; then
  exit 0
fi

if [[ ! -x $OPENFACTOR_BIN ]]; then
  echo "warning: OpenFactor CLI is not executable: $OPENFACTOR_BIN; skipping orchestration hook registration" >&2
  exit 0
fi

if ! "$OPENFACTOR_BIN" hooks install --scope host --json; then
  echo "warning: OpenFactor hook registration failed; continuing activation" >&2
fi

# Each hook boots the ~90 MB Bun CLI (~0.7 CPU-seconds) only to POST the event
# to the orchestration daemon socket, and drops it when no daemon listens there.
# Check the socket first so tool-call hooks cost nothing outside orchestrated
# lanes. Prompt events stay ungated: the CLI records lane prompt receipts from
# them without a daemon. The gated command still names openfactor, so later
# `hooks install` runs keep it instead of appending a second entry.
# shellcheck disable=SC2016
socket_gate='test -S "${OPENFACTOR_ORCHESTRATION_SOCKET:-${OPENFACTOR_ORCHESTRATION_STATE:-.orchestration-state}/daemon.sock}" || exit 0; exec '
receipts="${XDG_STATE_HOME:-$HOME/.local/state}/openfactor/hooks"
for receipt in "$receipts"/*.json; do
  [[ -f $receipt ]] || continue
  config="$(jq -r '.configPath // empty' "$receipt" 2>/dev/null || true)"
  [[ $config == *.json && -f $config && ! -L $config ]] || continue
  gated="$(mktemp "$config.XXXXXX")"
  if jq --arg gate "$socket_gate" '
    walk(
      if type == "string"
        and test("^openfactor [a-z]+-hook [A-Za-z.]+$")
        and (test("[Pp]rompt") | not)
      then "sh -c '\''" + $gate + . + "'\''"
      else . end
    )' "$config" >"$gated" && ! cmp -s "$gated" "$config"; then
    mv "$gated" "$config"
  else
    rm -f "$gated"
  fi
done
