#!/usr/bin/env bash
set -euo pipefail

keys_file="${1:?authorized keys file required}"
ssh_dir="${2:?SSH directory required}"
ssh_keygen="${3:?ssh-keygen binary required}"
authorized_keys="$ssh_dir/authorized_keys"
block_begin="# BEGIN dotfiles managed keys"
block_end="# END dotfiles managed keys"

while IFS= read -r key || [ -n "$key" ]; do
  [ -n "$key" ] || continue
  printf '%s\n' "$key" | "$ssh_keygen" -lf /dev/stdin >/dev/null
done <"$keys_file"

mkdir -p "$ssh_dir"
chmod 700 "$ssh_dir"
touch "$authorized_keys"
chmod 600 "$authorized_keys"

# The managed block is rewritten on every activation, so a key dropped from
# the declared list stops working. Entries outside the block are left alone,
# except copies of declared keys, which move into the block.
staged=$(mktemp "$ssh_dir/authorized_keys.XXXXXX")
trap 'rm -f "$staged"' EXIT
awk -v begin="$block_begin" -v end="$block_end" -v keys="$keys_file" '
  BEGIN { while ((getline key < keys) > 0) if (key != "") declared[key] = 1 }
  $0 == begin { inside = 1; next }
  $0 == end { inside = 0; next }
  inside || ($0 in declared) { next }
  { print }
' "$authorized_keys" >"$staged"
{
  printf '%s\n' "$block_begin"
  grep -v '^$' "$keys_file" || true
  printf '%s\n' "$block_end"
} >>"$staged"
chmod 600 "$staged"
mv "$staged" "$authorized_keys"
