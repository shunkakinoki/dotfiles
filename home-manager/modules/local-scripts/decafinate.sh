#!/usr/bin/env bash

set -euo pipefail

UNIT_NAME="decafinate"
UNIT_FILE="${UNIT_NAME}.service"

notify_local() {
  local message="$1"

  if [[ -x "$HOME/.local/scripts/notify-local" ]]; then
    "$HOME/.local/scripts/notify-local" "Decafinate" "$message" >/dev/null 2>&1 || true
  fi
}

print_usage() {
  cat <<'EOF'
Usage: decafinate [toggle|start|stop|status]

Manage an AC-only keep-awake session.

Commands:
  toggle  Start the session if inactive, otherwise stop it. Default.
  start   Start the session if AC power is connected.
  stop    Stop the session.
  status  Show whether the session is active.
EOF
}

ac_online() {
  local ac_path
  shopt -s nullglob

  for ac_path in /sys/class/power_supply/AC*/online; do
    if grep -q 1 "$ac_path"; then
      return 0
    fi
  done

  return 1
}

require_ac_path() {
  if ! compgen -G "/sys/class/power_supply/AC*/online" >/dev/null; then
    echo "No AC power status path found under /sys/class/power_supply/AC*/online" >&2
    notify_local "No AC power status path found."
    exit 1
  fi
}

service_active() {
  systemctl --user is-active --quiet "$UNIT_FILE"
}

print_status() {
  if service_active; then
    echo "decafinate is active"
    return 0
  fi

  echo "decafinate is inactive"
  return 1
}

start_service() {
  require_ac_path

  if service_active; then
    echo "decafinate is already active"
    return 0
  fi

  if ! ac_online; then
    echo "AC power is not connected; refusing to inhibit sleep on battery." >&2
    notify_local "AC power is not connected. Decafinate was not started."
    return 1
  fi

  local systemd_inhibit
  local bash_bin

  systemd_inhibit="$(command -v systemd-inhibit)"
  bash_bin="$(command -v bash)"

  if [[ -z "$systemd_inhibit" || -z "$bash_bin" ]]; then
    echo "Required commands not found: systemd-inhibit and bash must be available." >&2
    return 1
  fi

  echo "Starting decafinate. The laptop will stay awake while AC is connected."
  notify_local "Keeping the laptop awake while AC is connected."

  systemctl --user reset-failed "$UNIT_FILE" >/dev/null 2>&1 || true

  # shellcheck disable=SC2016
  systemd-run --user \
    --unit="$UNIT_NAME" \
    --collect \
    --property=Restart=no \
    --property=Type=simple \
    "$systemd_inhibit" \
      --what=idle:sleep:handle-lid-switch \
      --who="decafinate" \
      --why="Manual AC-only keep-awake session" \
      "$bash_bin" -lc '
        set -euo pipefail

        ac_online() {
          local ac_path
          shopt -s nullglob

          for ac_path in /sys/class/power_supply/AC*/online; do
            if grep -q 1 "$ac_path"; then
              return 0
            fi
          done

          return 1
        }

        while ac_online; do
          sleep 15
        done

        echo "AC power disconnected; ending decafinate session."
        if [[ -x "$HOME/.local/scripts/notify-local" ]]; then
          "$HOME/.local/scripts/notify-local" "Decafinate" "AC power disconnected. Ending keep-awake session." >/dev/null 2>&1 || true
        fi
      ' >/dev/null
}

stop_service() {
  if ! service_active; then
    echo "decafinate is already inactive"
    return 0
  fi

  systemctl --user stop "$UNIT_FILE"
  echo "Stopped decafinate"
  notify_local "Stopped the keep-awake session."
}

case "${1:-toggle}" in
  help|--help|-h)
    print_usage
    ;;
  toggle)
    if service_active; then
      stop_service
    else
      start_service
    fi
    ;;
  start)
    start_service
    ;;
  stop)
    stop_service
    ;;
  status)
    print_status
    ;;
  *)
    print_usage >&2
    exit 1
    ;;
esac
