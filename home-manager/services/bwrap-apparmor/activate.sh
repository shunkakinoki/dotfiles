#!/usr/bin/env bash
# Ubuntu 24.04 sets kernel.apparmor_restrict_unprivileged_userns=1, so the Nix
# store bwrap, which has no AppArmor profile, cannot configure the loopback in
# its network namespace and Codex sandboxed commands fail with
# "bwrap: loopback: Failed RTM_NEWADDR: Operation not permitted". Ubuntu grants
# its own /usr/bin/bwrap the same unconfined userns profile.
set -euo pipefail

APPARMOR_DIR="${BWRAP_APPARMOR_DIR:-/etc/apparmor.d}"
APPARMOR_PARSER="${BWRAP_APPARMOR_PARSER:-/usr/sbin/apparmor_parser}"
PROFILE="$APPARMOR_DIR/nix-bwrap"

if [ ! -d "$APPARMOR_DIR" ] || [ ! -x "$APPARMOR_PARSER" ]; then
  exit 0
fi

content='abi <abi/4.0>,
include <tunables/global>

profile nix-bwrap /nix/store/*-bubblewrap-*/bin/bwrap flags=(unconfined) {
  userns,

  include if exists <local/nix-bwrap>
}'

if [ -f "$PROFILE" ] && [ "$(cat "$PROFILE")" = "$content" ]; then
  exit 0
fi

run_root() {
  if [ "$(id -u)" = 0 ]; then
    "$@"
  else
    /usr/bin/sudo -n "$@"
  fi
}

printf '%s\n' "$content" | run_root tee "$PROFILE" >/dev/null
run_root "$APPARMOR_PARSER" -r "$PROFILE"
