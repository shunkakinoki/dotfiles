#!/usr/bin/env bash
# Install system-level tailscaled service and configure sudo PATH
# Usage: activate-install-service.sh <nix_service_file> <nix_profile_dir> [tailscale_up_service_file]
set -euo pipefail
NIX_SERVICE="$1"
NIX_PROFILE_DIR="$2"
UP_SERVICE="${3:-}"
SERVICE_FILE="/etc/systemd/system/tailscaled.service"
UP_SERVICE_FILE="/etc/systemd/system/tailscale-up.service"
SUDOERS_FILE="/etc/sudoers.d/nix-tailscale"

SUDO_CMD=""
if command -v sudo >/dev/null 2>&1; then
  SUDO_CMD="sudo"
elif [ -x /run/wrappers/bin/sudo ]; then
  SUDO_CMD="/run/wrappers/bin/sudo"
elif [ -x /usr/bin/sudo ]; then
  SUDO_CMD="/usr/bin/sudo"
elif command -v doas >/dev/null 2>&1; then
  SUDO_CMD="doas"
elif [ -x /usr/bin/doas ]; then
  SUDO_CMD="/usr/bin/doas"
elif [ "$(id -u)" -ne 0 ]; then
  echo "Tailscale system service installation requires root privileges, but sudo/doas is not available." >&2
  echo "Either install sudo, configure doas, or run home-manager as root." >&2
  exit 1
fi

run_root_cmd() {
  if [ -n "$SUDO_CMD" ]; then
    "$SUDO_CMD" "$@"
  else
    "$@"
  fi
}

# Only install if service file differs from nix-generated one
need_reload=false
if ! cmp -s "$NIX_SERVICE" "$SERVICE_FILE" 2>/dev/null; then
  echo "Installing tailscaled systemd service (requires root)..."
  run_root_cmd cp "$NIX_SERVICE" "$SERVICE_FILE"
  need_reload=true
  echo "Tailscaled service installed."
fi

if [ -n "$UP_SERVICE" ] && ! cmp -s "$UP_SERVICE" "$UP_SERVICE_FILE" 2>/dev/null; then
  echo "Installing tailscale-up systemd service (requires root)..."
  run_root_cmd cp "$UP_SERVICE" "$UP_SERVICE_FILE"
  need_reload=true
  echo "Tailscale-up service installed."
fi

if [ "$need_reload" = true ]; then
  run_root_cmd systemctl daemon-reload
fi

run_root_cmd systemctl enable tailscaled
if [ -n "$UP_SERVICE" ]; then
  run_root_cmd systemctl enable tailscale-up.service
  run_root_cmd systemctl restart tailscale-up.service
fi

# Configure sudo to include Nix profile paths
echo "Configuring sudo PATH for Nix packages..."
SUDOERS_CONTENT="# Added by home-manager for Nix Tailscale
Defaults secure_path=\"${NIX_PROFILE_DIR}/.nix-profile/bin:/nix/var/nix/profiles/default/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin\"
"

TEMP_SUDOERS=$(mktemp)
echo "$SUDOERS_CONTENT" >"$TEMP_SUDOERS"

if ! cmp -s "$TEMP_SUDOERS" "$SUDOERS_FILE" 2>/dev/null; then
  run_root_cmd cp "$TEMP_SUDOERS" "$SUDOERS_FILE"
  run_root_cmd chmod 0440 "$SUDOERS_FILE"
  echo "Sudo PATH configured. You can now use: sudo tailscale login"
fi

rm -f "$TEMP_SUDOERS"
