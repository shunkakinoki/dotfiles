#!/usr/bin/env bash
# Keep host and managed user services responsive when an SSH session is busy.
set -euo pipefail

USER_UID="$(id -u)"
readonly USER_UID
readonly SYSTEM_DROP_IN_FILE="/etc/systemd/system/system.slice.d/10-kyber-managed-services.conf"
readonly USER_DROP_IN_FILE="/etc/systemd/system/user@${USER_UID}.service.d/10-kyber-managed-services.conf"

ROOT_CMD=()
if command -v sudo >/dev/null 2>&1; then
  ROOT_CMD=(sudo -n)
elif [ -x /run/wrappers/bin/sudo ]; then
  ROOT_CMD=(/run/wrappers/bin/sudo -n)
elif [ -x /usr/bin/sudo ]; then
  ROOT_CMD=(/usr/bin/sudo -n)
elif command -v doas >/dev/null 2>&1; then
  ROOT_CMD=(doas -n)
elif [ "$(id -u)" -ne 0 ]; then
  echo "Managed service priority requires root privileges." >&2
  exit 1
fi

run_root() {
  if [ "${#ROOT_CMD[@]}" -gt 0 ]; then
    "${ROOT_CMD[@]}" "$@"
  else
    "$@"
  fi
}

SYSTEM_CONTENT=$(
  cat <<'EOF'
[Slice]
CPUWeight=1000
IOWeight=1000
EOF
)
USER_CONTENT=$(
  cat <<'EOF'
[Service]
CPUWeight=1000
IOWeight=1000
EOF
)

changed=0
install_drop_in() {
  local drop_in_file="$1"
  local content="$2"

  if [ -f "$drop_in_file" ] && printf '%s\n' "$content" | cmp -s - "$drop_in_file"; then
    return
  fi

  echo "Installing managed service priority at $drop_in_file..."
  run_root mkdir -p "$(dirname "$drop_in_file")"
  printf '%s\n' "$content" | run_root tee "$drop_in_file" >/dev/null
  run_root chmod 0644 "$drop_in_file"
  changed=1
}

apply_runtime_weights() {
  local unit="$1"
  local cpu_weight io_weight

  cpu_weight="$(run_root systemctl show "$unit" --property CPUWeight --value)"
  io_weight="$(run_root systemctl show "$unit" --property IOWeight --value)"
  if [ "$cpu_weight" = 1000 ] && [ "$io_weight" = 1000 ]; then
    return
  fi

  run_root systemctl set-property --runtime "$unit" CPUWeight=1000 IOWeight=1000
}

install_drop_in "$SYSTEM_DROP_IN_FILE" "$SYSTEM_CONTENT"
install_drop_in "$USER_DROP_IN_FILE" "$USER_CONTENT"
if [ "$changed" -eq 1 ]; then
  run_root systemctl daemon-reload
fi

# Restarts would interrupt managed services. Apply the weights to the running
# slices only when needed; the drop-ins own subsequent boots and logins.
apply_runtime_weights system.slice
apply_runtime_weights "user@${USER_UID}.service"

echo "Host and managed user services have priority over interactive sessions."
