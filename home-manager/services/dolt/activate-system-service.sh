#!/usr/bin/env bash
# Install the authoritative Beads SQL server as a root-managed system unit.
# @systemctl@ is substituted by pkgs.replaceVars.
set -euo pipefail

UNIT_FILE="$1"
readonly SYSTEM_UNIT="/etc/systemd/system/dolt.service"

ROOT_CMD=()
if command -v sudo >/dev/null 2>&1; then
  ROOT_CMD=(sudo -n)
elif [ -x /run/wrappers/bin/sudo ]; then
  ROOT_CMD=(/run/wrappers/bin/sudo -n)
elif [ -x /usr/bin/sudo ]; then
  ROOT_CMD=(/usr/bin/sudo -n)
elif [ "$(id -u)" -ne 0 ]; then
  echo "The Dolt system service requires root privileges." >&2
  exit 1
fi

run_root() {
  if [ "${#ROOT_CMD[@]}" -gt 0 ]; then
    "${ROOT_CMD[@]}" "$@"
  else
    "$@"
  fi
}

changed=0
if [ ! -f "$SYSTEM_UNIT" ] || ! cmp -s "$UNIT_FILE" "$SYSTEM_UNIT"; then
  echo "Installing $SYSTEM_UNIT..."
  run_root mkdir -p "$(dirname "$SYSTEM_UNIT")"
  run_root tee "$SYSTEM_UNIT" <"$UNIT_FILE" >/dev/null
  run_root chmod 0644 "$SYSTEM_UNIT"
  run_root @systemctl@ daemon-reload
  changed=1
fi

# The former user unit binds the same port, so it must release 3307 before the
# system unit starts. Home Manager removes its unit file after this step.
# Nix's newer systemctl cannot connect to the distribution's user manager, so
# user-scope calls use the host binary.
if /usr/bin/systemctl --user is-active --quiet dolt.service; then
  echo "Stopping the Dolt user service..."
  /usr/bin/systemctl --user stop dolt.service
fi

run_root @systemctl@ enable dolt.service
# Restart only for a changed unit; routine activations must not interrupt
# Beads clients.
if [ "$changed" -eq 1 ]; then
  run_root @systemctl@ restart dolt.service
else
  run_root @systemctl@ start dolt.service
fi
