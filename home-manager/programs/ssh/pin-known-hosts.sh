#!/usr/bin/env bash
# Pin declared host keys into ~/.ssh/known_hosts (append-if-missing).
set -euo pipefail

KNOWN_HOSTS_FILE="${1:?usage: pin-known-hosts.sh <source-file>}"

kh="$HOME/.ssh/known_hosts"
mkdir -p "$HOME/.ssh"
touch "$kh"
chmod 600 "$kh"

while IFS= read -r line; do
  [ -z "$line" ] && continue
  grep -qxF "$line" "$kh" || echo "$line" >>"$kh"
done <"$KNOWN_HOSTS_FILE"
