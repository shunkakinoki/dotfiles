#!/usr/bin/env bash
set -euo pipefail

expected=$(printf '%s' "${1:?expected host required}" | cut -d. -f1 | tr '[:upper:]' '[:lower:]')
is_named_host() {
  [[ $1 =~ ^(andor|beskar|kyber|matic|viper|galactica|kamino([1-9][0-9]*)?)$ ]]
}
# Generic profiles carry no named host policy.
is_named_host "$expected" || exit 0
physical=$(hostname | cut -d. -f1 | tr '[:upper:]' '[:lower:]')
tailnet=$(timeout 10 tailscale status --json 2>/dev/null | jq -r '.Self.DNSName // empty' | cut -d. -f1 | tr '[:upper:]' '[:lower:]') || tailnet=
verified=false
for actual in "$physical" "$tailnet"; do
  if is_named_host "$actual"; then
    if [ "$actual" != "$expected" ]; then
      printf 'Refusing profile %s on host %s; no host configuration was applied.\n' "$expected" "$actual" >&2
      exit 1
    fi
    verified=true
  fi
done
if [ "$verified" != true ]; then
  printf 'Cannot verify profile %s from the machine hostname or Tailscale identity.\n' "$expected" >&2
  exit 1
fi
