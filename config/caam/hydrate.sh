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

bridge_cursor_auth() {
  local source_auth="$1"
  local target_auth="$2"

  [[ -f $source_auth ]] || return 0
  mkdir -p "$(dirname "$target_auth")"

  if [[ -e $target_auth && ! -L $target_auth ]]; then
    if ! cmp -s "$source_auth" "$target_auth"; then
      echo "Preserving conflicting Cursor auth file at $target_auth" >&2
      return 0
    fi
    rm -f "$target_auth"
  fi

  ln -sfn ../../.cursor/auth.json "$target_auth"
}

# Cursor Agent reads the XDG path while CAAM manages ~/.cursor/auth.json.
# Bridge both the global credential and every isolated CAAM Cursor home without
# copying credential contents into dotfiles.
bridge_cursor_auth \
  "$HOME/.cursor/auth.json" \
  "$HOME/.config/cursor/auth.json"

shopt -s nullglob
for profile_dir in "$HOME/.local/share/caam/profiles/cursor"/*; do
  profile_home="$profile_dir/home"
  bridge_cursor_auth \
    "$profile_home/.cursor/auth.json" \
    "$profile_home/.config/cursor/auth.json"
done

echo "Hydrated CAAM config at $CONFIG_FILE" >&2
