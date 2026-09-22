#!/usr/bin/env bash
set -euo pipefail

keys_file="${1:?authorized keys file required}"
ssh_dir="${2:?SSH directory required}"
ssh_keygen="${3:?ssh-keygen binary required}"
authorized_keys="$ssh_dir/authorized_keys"

while IFS= read -r key || [ -n "$key" ]; do
  [ -n "$key" ] || continue
  printf '%s\n' "$key" | "$ssh_keygen" -lf /dev/stdin >/dev/null
done <"$keys_file"

mkdir -p "$ssh_dir"
chmod 700 "$ssh_dir"
touch "$authorized_keys"
chmod 600 "$authorized_keys"

while IFS= read -r key || [ -n "$key" ]; do
  [ -n "$key" ] || continue
  if grep -qxF "$key" "$authorized_keys"; then
    continue
  fi
  if [ -s "$authorized_keys" ] && [ "$(tail -c 1 "$authorized_keys" | wc -l)" -eq 0 ]; then
    printf '\n' >>"$authorized_keys"
  fi
  printf '%s\n' "$key" >>"$authorized_keys"
done <"$keys_file"
