#!/usr/bin/env bash
# Beskar's fleet runtime connects as root, but the host still carries Kyber's
# drop-in (PermitRootLogin no, AllowUsers ubuntu) from its original image.
# sshd keeps the first value it reads, so that file must go for root to log in.
set -euo pipefail
# Home Manager activation runs with a Nix-only PATH; sshd and systemctl live in
# the system directories.
export PATH="$PATH:/usr/sbin:/usr/bin:/sbin:/bin"

DROP_IN_DIR="${SSHD_CONFIG_DIR:-/etc/ssh/sshd_config.d}"
DROP_IN_FILE="${DROP_IN_DIR}/99-beskar-hardening.conf"
LEGACY_FILE="${DROP_IN_DIR}/99-kyber-hardening.conf"

CONTENT='# BEGIN beskar-hardening
PasswordAuthentication no
KbdInteractiveAuthentication no
PermitRootLogin prohibit-password
PubkeyAuthentication yes
AllowUsers root ubuntu
MaxAuthTries 3
AuthenticationMethods publickey
# END beskar-hardening'

if [ "$(id -u)" -ne 0 ]; then
  echo "Beskar sshd hardening requires root." >&2
  exit 1
fi

if [ ! -f "$LEGACY_FILE" ] && [ -f "$DROP_IN_FILE" ] &&
  printf '%s\n' "$CONTENT" | cmp -s - "$DROP_IN_FILE"; then
  exit 0
fi

echo "Installing sshd hardening drop-in at $DROP_IN_FILE..."
BACKUP_DIR=$(mktemp -d)
trap 'rm -rf "$BACKUP_DIR"' EXIT
for f in "$DROP_IN_FILE" "$LEGACY_FILE"; do
  if [ -f "$f" ]; then
    cp -p "$f" "$BACKUP_DIR/"
  fi
done

restore() {
  rm -f "$DROP_IN_FILE" "$LEGACY_FILE"
  cp -p "$BACKUP_DIR"/* "$DROP_IN_DIR/" 2>/dev/null || true
}

mkdir -p "$DROP_IN_DIR"
printf '%s\n' "$CONTENT" >"$DROP_IN_FILE"
chmod 0644 "$DROP_IN_FILE"
rm -f "$LEGACY_FILE"

if ! sshd -t; then
  echo "sshd -t failed; restoring the previous drop-ins." >&2
  restore
  exit 1
fi

# sshd -t only checks the files; the running daemon keeps the old policy until
# it reloads, so a failed reload must fail activation.
if ! systemctl reload ssh 2>/dev/null && ! systemctl reload sshd 2>/dev/null; then
  echo "Reloading sshd failed; restoring the previous drop-ins." >&2
  restore
  exit 1
fi
echo "sshd hardening applied."
