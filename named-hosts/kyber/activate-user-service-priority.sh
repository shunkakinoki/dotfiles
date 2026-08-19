#!/usr/bin/env bash
# Keep managed user services responsive when an abandoned SSH session is busy.
set -euo pipefail

USER_UID="$(id -u)"
DROP_IN_DIR="/etc/systemd/system/user@${USER_UID}.service.d"
DROP_IN_FILE="${DROP_IN_DIR}/10-kyber-managed-services.conf"

SUDO_CMD=""
if command -v sudo >/dev/null 2>&1; then
  SUDO_CMD="sudo"
elif [ -x /run/wrappers/bin/sudo ]; then
  SUDO_CMD="/run/wrappers/bin/sudo"
elif [ -x /usr/bin/sudo ]; then
  SUDO_CMD="/usr/bin/sudo"
elif command -v doas >/dev/null 2>&1; then
  SUDO_CMD="doas"
elif [ "$(id -u)" -ne 0 ]; then
  echo "Managed service priority requires root privileges." >&2
  exit 1
fi

run_root() {
  if [ -n "$SUDO_CMD" ]; then
    "$SUDO_CMD" "$@"
  else
    "$@"
  fi
}

CONTENT=$(
  cat <<'EOF'
[Service]
CPUWeight=1000
IOWeight=1000
EOF
)

if ! { [ -f "$DROP_IN_FILE" ] && printf '%s\n' "$CONTENT" | cmp -s - "$DROP_IN_FILE"; }; then
  echo "Installing managed service priority at $DROP_IN_FILE..."
  run_root mkdir -p "$DROP_IN_DIR"
  printf '%s\n' "$CONTENT" | run_root tee "$DROP_IN_FILE" >/dev/null
  run_root chmod 0644 "$DROP_IN_FILE"
  run_root systemctl daemon-reload
fi

# A user manager restart would interrupt every managed service. Apply the same
# weights to the current manager cgroup without restarting it; the drop-in owns
# the next boot/login.
run_root systemctl set-property --runtime "user@${USER_UID}.service" \
  CPUWeight=1000 IOWeight=1000

echo "Managed user services have priority over interactive session scopes."
