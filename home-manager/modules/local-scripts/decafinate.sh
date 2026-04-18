#!/usr/bin/env bash

set -euo pipefail

UNIT_NAME="decafinate"
UNIT_FILE="${UNIT_NAME}.service"
PID_FILE="${XDG_STATE_HOME:-$HOME/.local/state}/decafinate.pid"

OS="$(uname -s)"

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
  case "$OS" in
  Darwin)
    pmset -g ps | grep -q "AC Power"
    ;;
  Linux)
    local ac_path
    shopt -s nullglob

    for ac_path in /sys/class/power_supply/AC*/online; do
      if grep -q 1 "$ac_path"; then
        return 0
      fi
    done

    return 1
    ;;
  *)
    echo "Unsupported OS: $OS" >&2
    return 1
    ;;
  esac
}

require_ac() {
  case "$OS" in
  Darwin)
    if ! command -v pmset >/dev/null; then
      echo "pmset not found" >&2
      notify_local "pmset not found."
      exit 1
    fi
    ;;
  Linux)
    if ! compgen -G "/sys/class/power_supply/AC*/online" >/dev/null; then
      echo "No AC power status path found under /sys/class/power_supply/AC*/online" >&2
      notify_local "No AC power status path found."
      exit 1
    fi
    ;;
  esac
}

service_active() {
  case "$OS" in
  Darwin)
    if [[ -f $PID_FILE ]] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
      return 0
    fi
    return 1
    ;;
  Linux)
    systemctl --user is-active --quiet "$UNIT_FILE"
    ;;
  esac
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
  require_ac

  if service_active; then
    echo "decafinate is already active"
    return 0
  fi

  if ! ac_online; then
    echo "AC power is not connected; refusing to inhibit sleep on battery." >&2
    notify_local "AC power is not connected. Decafinate was not started."
    return 1
  fi

  echo "Starting decafinate. The laptop will stay awake while AC is connected."
  notify_local "Keeping the laptop awake while AC is connected."

  case "$OS" in
  Darwin)
    mkdir -p "$(dirname "$PID_FILE")"

    (
      caffeinate -di &
      CAFF_PID=$!

      while ac_online; do
        if ! kill -0 "$CAFF_PID" 2>/dev/null; then
          break
        fi
        sleep 15
      done

      kill "$CAFF_PID" 2>/dev/null || true
      rm -f "$PID_FILE"

      echo "AC power disconnected; ending decafinate session."
      if [[ -x "$HOME/.local/scripts/notify-local" ]]; then
        "$HOME/.local/scripts/notify-local" "Decafinate" "AC power disconnected. Ending keep-awake session." >/dev/null 2>&1 || true
      fi
    ) &
    echo $! >"$PID_FILE"
    disown
    ;;
  Linux)
    local systemd_inhibit
    local bash_bin

    systemd_inhibit="$(command -v systemd-inhibit)"
    bash_bin="$(command -v bash)"

    if [[ -z $systemd_inhibit || -z $bash_bin ]]; then
      echo "Required commands not found: systemd-inhibit and bash must be available." >&2
      return 1
    fi

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
    ;;
  esac
}

stop_service() {
  if ! service_active; then
    echo "decafinate is already inactive"
    return 0
  fi

  case "$OS" in
  Darwin)
    local pid
    pid="$(cat "$PID_FILE")"
    # Kill the wrapper process group (includes caffeinate)
    kill -- -"$pid" 2>/dev/null || kill "$pid" 2>/dev/null || true
    rm -f "$PID_FILE"
    ;;
  Linux)
    systemctl --user stop "$UNIT_FILE"
    ;;
  esac

  echo "Stopped decafinate"
  notify_local "Stopped the keep-awake session."
}

case "${1:-toggle}" in
help | --help | -h)
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
