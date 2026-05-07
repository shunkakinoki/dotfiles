#!/usr/bin/env bash
# Lock through Noctalia on the physical lid-close transition.
set -euo pipefail

NOCTALIA_SHELL="@noctalia_shell@"
SLEEP="@sleep@"

find_lid_state_file() {
  local path

  for path in /proc/acpi/button/lid/*/state; do
    [ -f "$path" ] || continue
    printf '%s\n' "$path"
    return 0
  done

  return 1
}

read_lid_state() {
  local path="$1"
  local line

  IFS= read -r line <"$path" || return 1

  case "$line" in
  *closed*) printf '%s\n' closed ;;
  *open*) printf '%s\n' open ;;
  *) printf '%s\n' unknown ;;
  esac
}

lock_noctalia() {
  "$NOCTALIA_SHELL" ipc call lockScreen lock >/dev/null 2>&1 || true
}

last_state=""

while true; do
  lid_state_file="$(find_lid_state_file || true)"
  if [ -z "$lid_state_file" ]; then
    "$SLEEP" 5
    continue
  fi

  lid_state="$(read_lid_state "$lid_state_file" || printf '%s\n' unknown)"
  if [ "$lid_state" = closed ] && [ "$last_state" != closed ]; then
    lock_noctalia
  fi

  last_state="$lid_state"
  "$SLEEP" 1
done
