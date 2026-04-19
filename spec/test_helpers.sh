#!/usr/bin/env bash

set -euo pipefail

# Portable alternative to `dirname "$(readlink -f "$(command -v cmd)")"`.
# macOS BSD readlink lacks -f; this uses Python as fallback.
resolve_cmd_dir() {
  local cmd_path
  cmd_path="$(command -v "$1")"
  if readlink -f "$cmd_path" >/dev/null 2>&1; then
    dirname "$(readlink -f "$cmd_path")"
  else
    dirname "$(python3 -c "import os; print(os.path.realpath('$cmd_path'))")"
  fi
}

# Portable file permission query (octal). macOS stat uses -f, GNU uses -c.
portable_stat_perms() {
  if stat -c '%a' "$1" 2>/dev/null; then
    return
  fi
  stat -f '%Lp' "$1"
}

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

# Preprocess a Nix script by replacing @placeholder@ with actual commands
# Usage: nix_script_preprocess /path/to/script.sh
# Returns: Path to preprocessed script in temp directory
nix_script_preprocess() {
  local script="$1"
  local processed_dir="${NIX_SCRIPT_TEMP:-$(mktemp -d)}"
  local basename
  basename=$(basename "$script")
  local processed="$processed_dir/$basename"

  export NIX_SCRIPT_TEMP="$processed_dir"

  # Replace @placeholder@ patterns with actual commands
  sed \
    -e "s|@aws@|aws|g" \
    -e "s|@rsync@|rsync|g" \
    -e "s|@bash@|bash|g" \
    -e "s|@sed@|sed|g" \
    -e "s|@find@|$(command -v find)|g" \
    -e "s|@stat@|$(command -v stat)|g" \
    "$script" >"$processed"

  chmod +x "$processed"
  echo "$processed"
}

# Preprocess scripts that reference other scripts (like backup-and-recover.sh)
# Usage: nix_script_preprocess_with_deps /path/to/script.sh script1.sh script2.sh ...
nix_script_preprocess_with_deps() {
  local script="$1"
  shift
  local scripts_dir
  scripts_dir=$(dirname "$script")
  local processed_dir="${NIX_SCRIPT_TEMP:-$(mktemp -d)}"
  local basename
  basename=$(basename "$script")
  local processed="$processed_dir/$basename"

  export NIX_SCRIPT_TEMP="$processed_dir"

  # First preprocess all dependency scripts
  local dep_script
  for dep_script in "$@"; do
    nix_script_preprocess "$scripts_dir/$dep_script" >/dev/null
  done

  # Now preprocess the main script with script path replacements
  # Replace @placeholder@ patterns with actual commands
  sed \
    -e 's|@aws@|aws|g' \
    -e 's|@rsync@|rsync|g' \
    -e 's|@bash@|bash|g' \
    -e 's|@sed@|sed|g' \
    -e "s|@backupAuthScript@|$processed_dir/backup-auth.sh|g" \
    -e "s|@recoverAuthScript@|$processed_dir/recover-auth.sh|g" \
    "$script" >"$processed"

  chmod +x "$processed"
  echo "$processed"
}

nix_script_cleanup() {
  if [[ -n ${NIX_SCRIPT_TEMP:-} ]]; then
    rm -rf "$NIX_SCRIPT_TEMP"
  fi
  unset NIX_SCRIPT_TEMP
}
