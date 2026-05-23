#!/usr/bin/env bash

# Cursor Pushover notification hook
# Sends notifications to phone/watch via the shared pushover-notify script.

export PATH="$HOME/.cargo/bin:/etc/profiles/per-user/shunkakinoki/bin:/run/current-system/sw/bin:/nix/var/nix/profiles/default/bin:/opt/homebrew/bin:/usr/local/bin:/usr/sbin:/usr/bin:/bin:${PATH:-}"

command -v jq >/dev/null 2>&1 || exit 0

input=$(cat)

pushover="$(command -v pushover-notify 2>/dev/null || true)"
if [[ -z $pushover ]] && [[ -x "$HOME/.local/scripts/pushover-notify" ]]; then
  pushover="$HOME/.local/scripts/pushover-notify"
fi
[[ -z $pushover ]] && exit 0

HOSTNAME=$(scutil --get ComputerName 2>/dev/null || hostname -s 2>/dev/null || echo "unknown")
CWD=$(echo "$input" | jq -r '.cwd // (.workspace_roots[0] // empty)' 2>/dev/null | sed "s|$HOME|~|")

event=$(echo "$input" | jq -r '.hook_event_name // empty' 2>/dev/null)

case "$event" in
stop)
  # Cursor doesn't honor async on hooks; background the network call so the
  # agent loop isn't held open waiting on Pushover's HTTP roundtrip.
  (
    status=$(echo "$input" | jq -r '.status // "completed"' 2>/dev/null)
    case "$status" in
    completed) "$pushover" "Cursor" "[$HOSTNAME] Work completed${CWD:+ in $CWD}" 0 ;;
    aborted) "$pushover" "Cursor" "[$HOSTNAME] Work aborted${CWD:+ in $CWD}" 0 ;;
    error) "$pushover" "Cursor" "[$HOSTNAME] Work errored${CWD:+ in $CWD}" 1 ;;
    esac
  ) </dev/null >/dev/null 2>&1 &
  disown 2>/dev/null || true
  ;;
beforeShellExecution)
  command=$(echo "$input" | jq -r '.command // empty' 2>/dev/null)
  if echo "$command" | grep -qiE 'rm -rf|drop database|truncate|DELETE FROM|format'; then
    risky_msg=$(echo "$command" | head -c 100)
    "$pushover" "Cursor" "[$HOSTNAME] Risky: ${risky_msg}" 1
  fi
  ;;
esac

exit 0
