#!/usr/bin/env bash
# Hydrate Handy settings_store.json from template, injecting OPENROUTER_API_KEY
# from ~/dotfiles/.env at activation time.
# shellcheck source=/dev/null
set -euo pipefail

DOTFILES_DIR="${HOME}/dotfiles"
# Hydrate the post-llm-update artifact (model placeholders already substituted
# by scripts/llm-update.sh from models.json). We only inject the API key here.
TEMPLATE="${DOTFILES_DIR}/config/handy/settings_store.template.json"
ENV_FILE="${DOTFILES_DIR}/.env"

case "$(uname -s)" in
  Darwin) DEST_DIR="$HOME/Library/Application Support/com.pais.handy" ;;
  Linux)  DEST_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/com.pais.handy" ;;
  *) echo "handy hydrate: unsupported OS $(uname -s)" >&2; exit 0 ;;
esac

if [ ! -f "$TEMPLATE" ]; then
  echo "handy hydrate: template missing at $TEMPLATE" >&2
  exit 0
fi

if [ -f "$ENV_FILE" ]; then
  set -a
  . "$ENV_FILE"
  set +a
fi

if [ -z "${OPENROUTER_API_KEY:-}" ]; then
  echo "Warning: OPENROUTER_API_KEY not set, Handy post-processing will be unauthenticated" >&2
fi

mkdir -p "$DEST_DIR"
TMP="$(mktemp)"
@sed@ \
  -e "s|__OPENROUTER_API_KEY__|${OPENROUTER_API_KEY:-}|g" \
  "$TEMPLATE" >"$TMP"
install -m 0600 "$TMP" "$DEST_DIR/settings_store.json"
rm -f "$TMP"
echo "Hydrated Handy settings_store.json at $DEST_DIR" >&2
