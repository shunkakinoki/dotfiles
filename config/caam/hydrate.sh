#!/usr/bin/env bash
# Hydrate CAAM's host-specific, non-secret runtime configuration.
set -euo pipefail

CONFIG_DIR="${HOME}/.caam"
CONFIG_FILE="${CONFIG_DIR}/config.yaml"
TEMPLATE="@template@"
AUTO_ROTATE="@autoRotate@"
TMP_FILE="$(mktemp)"
trap 'rm -f "$TMP_FILE"' EXIT

mkdir -p "$CONFIG_DIR"
@sed@ \
  -e "s|__AUTO_ROTATE__|${AUTO_ROTATE}|g" \
  "$TEMPLATE" >"$TMP_FILE"
install -m 0600 "$TMP_FILE" "$CONFIG_FILE"

echo "Hydrated CAAM config at $CONFIG_FILE" >&2
