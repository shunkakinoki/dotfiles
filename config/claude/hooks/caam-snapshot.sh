#!/usr/bin/env bash
# Preserve Claude's rotated OAuth credential in the matching local CAAM profile.
# SessionEnd hooks are best-effort: authentication and CAAM failures must never
# prevent Claude from exiting.

set -u

# Consume the hook payload even though the authenticated identity is read from
# Claude's credential store rather than inferred from session metadata.
cat >/dev/null

for command_name in caam claude jq; do
  if ! command -v "$command_name" >/dev/null 2>&1; then
    exit 0
  fi
done

AUTH_STATUS=$(claude auth status --json 2>/dev/null) || exit 0
EMAIL=$(printf '%s' "$AUTH_STATUS" | jq -r '
  if .loggedIn == true then (.email // empty) else empty end
' 2>/dev/null) || exit 0

# Only update an existing email-named profile. This prevents a malformed or
# unauthenticated status response from creating a new vault entry.
case "$EMAIL" in
*@*.*) ;;
*) exit 0 ;;
esac

if ! caam ls claude --json 2>/dev/null | jq -e --arg email "$EMAIL" '
  any(.profiles[]?; .name == $email)
' >/dev/null 2>&1; then
  exit 0
fi

caam backup claude "$EMAIL" >/dev/null 2>&1 || true
exit 0
