#!/usr/bin/env bash
# Bootstrap or recover Claude CAAM vault profiles on managed remote hosts.
# Galactica is the one-way source; runtime token rotation remains host-local.
set -euo pipefail
umask 077

SOURCE_HOST="${CAAM_SYNC_SOURCE_HOST:-${HOSTNAME:-}}"
TARGETS="${CAAM_SYNC_TARGETS:-matic kyber}"
PROFILES="${CAAM_SYNC_PROFILES:-shunkakinoki@gmail.com shunkakinoki@shunkakinoki.com}"
ACTIVE_PROFILE="${CAAM_SYNC_ACTIVE_PROFILE:-shunkakinoki@shunkakinoki.com}"
VERIFY="${CAAM_SYNC_VERIFY:-0}"

if [[ -z $SOURCE_HOST ]] && command -v scutil >/dev/null 2>&1; then
  SOURCE_HOST=$(scutil --get LocalHostName 2>/dev/null || true)
fi
if [[ -z $SOURCE_HOST ]] && command -v hostname >/dev/null 2>&1; then
  SOURCE_HOST=$(hostname -s 2>/dev/null || true)
fi
SOURCE_HOST=${SOURCE_HOST,,}
SOURCE_HOST=${SOURCE_HOST%%.*}

if [[ $SOURCE_HOST != galactica ]]; then
  echo "Refusing CAAM credential export from '$SOURCE_HOST'; run this on Galactica." >&2
  exit 1
fi

for command_name in caam claude ssh jq; do
  if ! command -v "$command_name" >/dev/null 2>&1; then
    echo "Required command not found: $command_name" >&2
    exit 1
  fi
done

AUTH_STATUS=$(claude auth status --json 2>/dev/null || true)
if ! jq -e --arg active "$ACTIVE_PROFILE" '
  .loggedIn == true and .email == $active
' <<<"$AUTH_STATUS" >/dev/null; then
  echo "Galactica is not logged in to the preferred Claude account: $ACTIVE_PROFILE" >&2
  echo "Run 'claude auth login --email $ACTIVE_PROFILE', then retry the sync." >&2
  exit 1
fi

# Capture the currently provider-validated credential before exporting anything.
caam backup claude "$ACTIVE_PROFILE" >/dev/null

if ! caam ls claude --json | jq -e --arg active "$ACTIVE_PROFILE" '
  any(.profiles[]?; .name == $active)
' >/dev/null; then
  echo "Active Claude profile is not present in Galactica's CAAM vault: $ACTIVE_PROFILE" >&2
  exit 1
fi

ARCHIVE_DIR=$(mktemp -d)
trap 'rm -rf "$ARCHIVE_DIR"' EXIT
chmod 0700 "$ARCHIVE_DIR"

for profile in $PROFILES; do
  if ! caam ls claude --json | jq -e --arg profile "$profile" '
    any(.profiles[]?; .name == $profile)
  ' >/dev/null; then
    echo "Claude profile is not present in Galactica's CAAM vault: $profile" >&2
    exit 1
  fi

  archive="$ARCHIVE_DIR/${profile//[^a-zA-Z0-9._-]/_}.tar.gz"
  caam export "claude/$profile" --output "$archive" >/dev/null

  for target in $TARGETS; do
    echo "Importing Claude profile '$profile' on $target..." >&2
    ssh -o BatchMode=yes "$target" 'caam import - --force >/dev/null' <"$archive"
  done
done

for target in $TARGETS; do
  echo "Activating Claude profile '$ACTIVE_PROFILE' on $target..." >&2
  ssh -o BatchMode=yes "$target" \
    "caam activate claude '$ACTIVE_PROFILE' --force >/dev/null"

  if [[ $VERIFY == 1 ]]; then
    echo "Verifying Claude authentication on $target..." >&2
    ssh -o BatchMode=yes "$target" \
      "timeout 90 fish -lc '_clxe_function \"Reply exactly OK\"'"
  fi
done

echo "Claude CAAM profiles synced from Galactica to: $TARGETS" >&2
