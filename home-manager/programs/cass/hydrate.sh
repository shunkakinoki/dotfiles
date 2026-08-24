#!/usr/bin/env bash
# Hydrate cass remote sources for the machine this runs on.
# cass only pulls, so every host lists each peer except itself; a peer that
# listed itself would rsync its own sessions back over SSH.
set -euo pipefail

# name|ssh target|platform|hostnames that identify this machine
PEERS=(
  "kyber|ubuntu@kyber|linux|kyber"
  "matic|shunkakinoki@matic|linux|matic"
)

# Session directories every Linux peer exposes over SSH. The tildes are
# expanded by cass on the remote, not by this shell.
# shellcheck disable=SC2088
PATHS=(
  "~/.claude/projects"
  "~/.codex/sessions"
  "~/.config/Code/User/globalStorage/saoudrizwan.claude-dev"
  "~/.config/Code/User/globalStorage/rooveterinaryinc.roo-cline"
  "~/.config/Cursor/User/globalStorage/saoudrizwan.claude-dev"
  "~/.config/Cursor/User/globalStorage/rooveterinaryinc.roo-cline"
  "~/.gemini/tmp"
  "~/.pi/agent/sessions"
  "~/.local/share/opencode/storage"
  "~/.continue/sessions"
  "~/.aider.chat.history.md"
  "~/.goose/sessions"
)

SELF="${HOST:-${HOSTNAME:-}}"
if [ -z "$SELF" ]; then
  SELF="$(hostname 2>/dev/null || uname -n)"
fi
SELF="${SELF%%.*}"

if [ "$(uname -s)" = "Darwin" ]; then
  CONFIG_DIR="${HOME}/Library/Application Support/cass"
else
  CONFIG_DIR="${XDG_CONFIG_HOME:-${HOME}/.config}/cass"
fi

is_self() {
  local aliases="$1"
  local alias
  for alias in $aliases; do
    if [ "$alias" = "$SELF" ]; then
      return 0
    fi
  done
  return 1
}

TMP_FILE="$(mktemp)"
trap 'rm -f "$TMP_FILE"' EXIT

for peer in "${PEERS[@]}"; do
  IFS='|' read -r name target platform aliases <<<"$peer"

  if is_self "$aliases"; then
    continue
  fi

  {
    printf '[[sources]]\n'
    printf 'name = "%s"\n' "$name"
    printf 'type = "ssh"\n'
    printf 'host = "%s"\n' "$target"
    printf 'paths = [\n'
    for path in "${PATHS[@]}"; do
      printf '  "%s",\n' "$path"
    done
    printf ']\n'
    printf 'sync_schedule = "daily"\n'
    printf 'path_mappings = []\n'
    printf 'platform = "%s"\n\n' "$platform"
  } >>"$TMP_FILE"
done

mkdir -p "$CONFIG_DIR"
# Older generations symlinked this file into the Nix store; replace it.
rm -f "${CONFIG_DIR}/sources.toml"
install -m 644 "$TMP_FILE" "${CONFIG_DIR}/sources.toml"

echo "Hydrated cass sources for ${SELF} at ${CONFIG_DIR}/sources.toml" >&2
