#!/usr/bin/env bash
# Copy Codex config files, add optional live orchestration hooks, and synchronize
# managed Desktop settings.
# Usage: activate.sh <config_toml> <hooks_json> <desktop_settings_json> <jq_bin> <sync_script> <profiles_dir> [merge_hooks_script]
set -euo pipefail
CONFIG_TOML="$1"
HOOKS_JSON="$2"
DESKTOP_SETTINGS_JSON="$3"
JQ_BIN="$4"
SYNC_SCRIPT="$5"
PROFILES_DIR="$6"
MERGE_HOOKS_SCRIPT="${7:-$(dirname "${BASH_SOURCE[0]}")/merge-orchestration-hooks.sh}"

# Codex records directory trust ([projects.*]) and hook trust ([hooks.state.*])
# in the same files this script replaces. Carry those tables into the new copy
# so activation does not revoke trust and stall every session at a prompt.
TRUST_TABLE_PATTERN='^[[:space:]]*\[(projects\.|hooks\.state[].])'

# Prints the multiline string delimiter still open after a TOML line, given
# the one open before it. Single-line strings, escapes, and comments are
# scanned so their quote characters never open or close a multiline string.
toml_open_string() {
  local line="$1" state="$2" i=0 c
  while ((i < ${#line})); do
    c=${line:i:1}
    # shfmt normalizes the backslash literal to '\', which SC1003 misreads.
    # shellcheck disable=SC1003
    if [[ -z $state ]]; then
      [[ $c == '#' ]] && break
      if [[ $c == '"' || $c == "'" ]]; then
        if [[ ${line:i:3} == "$c$c$c" ]]; then state=$c$c$c; else state=$c; fi
        ((i += ${#state}))
        continue
      fi
    elif [[ $c == '\' && ${state:0:1} == '"' ]]; then
      ((i += 2))
      continue
    elif [[ $c == "${state:0:1}" && (${#state} == 1 || ${line:i:3} == "$state") ]]; then
      # A closing delimiter may carry up to two extra quote characters.
      while [[ ${line:i:1} == "$c" ]]; do ((i += 1)); done
      state=""
      continue
    fi
    ((i += 1))
  done
  # Only multiline strings continue onto the next line.
  if ((${#state} == 3)); then printf '%s' "$state"; fi
}

install_config() {
  local source="$1" destination="$2" preserved="" keep=0 line delim=""
  if [[ -f $destination ]]; then
    while IFS= read -r line || [[ -n $line ]]; do
      # A bracketed line inside a multiline string is string content, not a
      # table header.
      if [[ -z $delim && $line =~ ^[[:space:]]*\[ ]]; then
        if [[ $line =~ $TRUST_TABLE_PATTERN ]]; then keep=1; else keep=0; fi
      fi
      if ((keep)); then preserved+="$line"$'\n'; fi
      delim=$(toml_open_string "$line" "$delim")
    done <"$destination"
  fi
  cp -f "$source" "$destination"
  chmod 600 "$destination"
  if [[ -n $preserved ]]; then
    printf '\n%s' "$preserved" >>"$destination"
  fi
}

mkdir -p ~/.codex/hooks
for profile in "$PROFILES_DIR"/*.config.toml; do
  install_config "$profile" "$HOME/.codex/$(basename "$profile")"
done
install_config "$CONFIG_TOML" ~/.codex/config.toml
cp -f "$HOOKS_JSON" ~/.codex/hooks.json
chmod 644 ~/.codex/hooks.json

"$MERGE_HOOKS_SCRIPT" "$HOME/.codex/hooks.json" "$JQ_BIN"

"$SYNC_SCRIPT" "$DESKTOP_SETTINGS_JSON" "$JQ_BIN"
