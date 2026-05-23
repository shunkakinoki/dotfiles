#!/usr/bin/env bash

# Cursor local notification hook
# Sends native OS notifications via the shared notify-local script.
# Skips local popups when Pushover is configured (pushover.sh handles those).

export PATH="$HOME/.cargo/bin:/etc/profiles/per-user/shunkakinoki/bin:/run/current-system/sw/bin:/nix/var/nix/profiles/default/bin:/opt/homebrew/bin:/usr/local/bin:/usr/sbin:/usr/bin:/bin:${PATH:-}"

command -v jq >/dev/null 2>&1 || exit 0

if [[ -z ${PUSHOVER_API_TOKEN:-} ]] || [[ -z ${PUSHOVER_USER_KEY:-} ]]; then
  if [[ -f "$HOME/dotfiles/.env" ]]; then
    set -a
    # shellcheck source=/dev/null
    source "$HOME/dotfiles/.env" 2>/dev/null
    set +a
  fi
fi

# Skip local popups only when Pushover is BOTH configured AND deliverable —
# otherwise fall back to local so we don't go silent on a missing binary.
if [[ -n ${PUSHOVER_API_TOKEN:-} ]] && [[ -n ${PUSHOVER_USER_KEY:-} ]] && \
   { command -v pushover-notify >/dev/null 2>&1 || [[ -x "$HOME/.local/scripts/pushover-notify" ]]; }; then
  exit 0
fi

input=$(cat)

notify() {
  local message="$1"
  local sound="${2:-Sonar}"
  local notifier

  [[ -z $message ]] && return

  notifier="$(command -v notify-local 2>/dev/null || true)"
  if [[ -z $notifier ]] && [[ -x "$HOME/.local/scripts/notify-local" ]]; then
    notifier="$HOME/.local/scripts/notify-local"
  fi

  [[ -n $notifier ]] && "$notifier" "Cursor" "$message" "$sound"
}

event=$(echo "$input" | jq -r '.hook_event_name // empty' 2>/dev/null)

case "$event" in
stop)
  # Cursor doesn't honor async on hooks; background the work so the agent
  # loop isn't held open waiting for the notifier to return.
  (
    status=$(echo "$input" | jq -r '.status // "completed"' 2>/dev/null)
    case "$status" in
    completed) notify "Work completed" ;;
    aborted) notify "Work aborted" "Basso" ;;
    error) notify "Work errored" "Basso" ;;
    esac
  ) </dev/null >/dev/null 2>&1 &
  disown 2>/dev/null || true
  ;;
beforeShellExecution)
  command=$(echo "$input" | jq -r '.command // empty' 2>/dev/null)
  if echo "$command" | grep -qiE 'rm -rf|drop database|truncate|DELETE FROM|format'; then
    risky_msg=$(echo "$command" | head -c 100)
    notify "Risky: ${risky_msg}" "Basso"
  fi
  ;;
esac

exit 0
