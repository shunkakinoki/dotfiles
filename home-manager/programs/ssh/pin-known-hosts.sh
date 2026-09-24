#!/usr/bin/env bash
# Pin declared host keys into ~/.ssh/known_hosts.
# The awk path is substituted by pkgs.replaceVars so activation does not depend
# on awk being on the generated activation PATH.
set -euo pipefail

KNOWN_HOSTS_FILE="${1:?usage: pin-known-hosts.sh <source-file>}"

kh="$HOME/.ssh/known_hosts"
mkdir -p "$HOME/.ssh"
touch "$kh"
chmod 600 "$kh"

pinned=$(mktemp)
trap 'rm -f "$pinned"' EXIT

# Appending alone leaves a rotated host's superseded key trusted for as long as
# the file lives, because OpenSSH accepts either key while both are present.
# Drop every line that carries a declared host, then write the declared set
# back, so a switch restores exactly the trust this repository declares. Lines
# for hosts this repository does not declare are left alone.
# shellcheck disable=SC2016
@awk@ 'NR == FNR { if (NF >= 3) declared[$1] = 1; next }
     NF < 3 { print; next }
     {
       count = split($1, patterns, ",")
       for (index_ = 1; index_ <= count; index_++)
         if (patterns[index_] in declared) next
       print
     }' "$KNOWN_HOSTS_FILE" "$kh" >"$pinned"
cat "$KNOWN_HOSTS_FILE" >>"$pinned"

cmp -s "$pinned" "$kh" || cat "$pinned" >"$kh"
