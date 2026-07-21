#!/usr/bin/env bash
# Install declarative OpenSSH hardening drop-in for Kyber.
set -euo pipefail

DROP_IN_DIR="/etc/ssh/sshd_config.d"
DROP_IN_FILE="${DROP_IN_DIR}/99-kyber-hardening.conf"
MARKER_BEGIN="# BEGIN kyber-hardening"
MARKER_END="# END kyber-hardening"

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
  echo "sshd hardening requires root privileges." >&2
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
  cat <<EOF
${MARKER_BEGIN}
PasswordAuthentication no
KbdInteractiveAuthentication no
PermitRootLogin no
PubkeyAuthentication yes
AllowUsers ubuntu
MaxAuthTries 3
AuthenticationMethods publickey
${MARKER_END}
EOF
)

if [ -f "$DROP_IN_FILE" ] && printf '%s\n' "$CONTENT" | cmp -s - "$DROP_IN_FILE"; then
  echo "sshd hardening already up to date at $DROP_IN_FILE"
  exit 0
fi

echo "Installing sshd hardening drop-in at $DROP_IN_FILE..."
run_root mkdir -p "$DROP_IN_DIR"
printf '%s\n' "$CONTENT" | run_root tee "$DROP_IN_FILE" >/dev/null
run_root chmod 0644 "$DROP_IN_FILE"

if run_root sshd -t; then
  if command -v systemctl >/dev/null 2>&1; then
    run_root systemctl reload ssh 2>/dev/null || run_root systemctl reload sshd 2>/dev/null || true
  fi
  echo "sshd hardening applied."
else
  echo "sshd -t failed after writing $DROP_IN_FILE; leaving file for inspection." >&2
  exit 1
fi
