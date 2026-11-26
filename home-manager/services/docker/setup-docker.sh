#!/usr/bin/env bash
# Ensures the user is in the docker group and the system Docker daemon is running.
# @shadow@, @gnugrep@, @systemd@, @coreutils@, @docker_service_file@, @docker_daemon_file@, @diffutils@
# are substituted by pkgs.replaceVars.
set -euo pipefail

NON_INTERACTIVE=false
for arg in "$@"; do
  case "$arg" in
  --non-interactive)
    NON_INTERACTIVE=true
    ;;
  *) ;;
  esac
done

# Skip on NixOS - Docker is managed declaratively via virtualisation.docker.
if [ -e /etc/NIXOS ]; then
  exit 0
fi

# Skip when not booted with systemd (sd_booted(3), e.g. containers or CI runners).
if [ ! -d /run/systemd/system ]; then
  exit 0
fi

# Home Manager activation runs with a Nix-only PATH; append host system dirs so
# getent and sudo resolve on non-NixOS Linux hosts without overriding test mocks.
export PATH="${PATH}:/run/wrappers/bin:/usr/sbin:/usr/bin:/sbin:/bin"

# Define paths
ID_CMD=@coreutils@/bin/id
GROUPADD=@shadow@/bin/groupadd
GREP=@gnugrep@/bin/grep
USERMOD=@shadow@/bin/usermod
SYSTEMCTL=@systemd@/bin/systemctl
TEE=@coreutils@/bin/tee
MKDIR=@coreutils@/bin/mkdir
INSTALL=@coreutils@/bin/install
DIFF=@diffutils@/bin/diff
DOCKER_SERVICE_FILE=@docker_service_file@
DOCKER_DAEMON_FILE=@docker_daemon_file@
SYSTEM_SERVICE=/etc/systemd/system/docker.service
DOCKER_CONFIG_DIR=/etc/docker
DOCKER_DAEMON_CONFIG="$DOCKER_CONFIG_DIR/daemon.json"
SYSCTL_CONF=/etc/sysctl.d/99-docker-inotify.conf
TARGET_USER="${USER:-$("$ID_CMD" -un)}"

SUDO_BIN=""
if command -v sudo >/dev/null 2>&1; then
  SUDO_BIN="$(command -v sudo)"
elif [ -x /run/wrappers/bin/sudo ]; then
  SUDO_BIN="/run/wrappers/bin/sudo"
elif [ -x /usr/bin/sudo ]; then
  SUDO_BIN="/usr/bin/sudo"
fi

run_root() {
  if [ "$("$ID_CMD" -u)" -eq 0 ]; then
    "$@"
  elif [ "$NON_INTERACTIVE" = true ]; then
    "$SUDO_BIN" -n "$@"
  else
    "$SUDO_BIN" "$@"
  fi
}

if [ "$("$ID_CMD" -u)" -ne 0 ]; then
  if [ "$NON_INTERACTIVE" = true ]; then
    if [ -z "$SUDO_BIN" ] || ! "$SUDO_BIN" -n true >/dev/null 2>&1; then
      echo "Skipping Docker setup (non-interactive root access unavailable)" >&2
      exit 0
    fi
  elif [ -z "$SUDO_BIN" ]; then
    echo "Docker setup requires root privileges, but sudo is not available." >&2
    exit 1
  fi
fi

# Ensure docker group exists
if ! getent group docker >/dev/null 2>&1; then
  echo "Creating docker group..."
  run_root "$GROUPADD" docker
fi

# Check if user is in docker group
if ! "$ID_CMD" -Gn "$TARGET_USER" 2>/dev/null | "$GREP" -qE '(^| )docker( |$)'; then
  echo "Adding user to docker group..."
  run_root "$USERMOD" -aG docker "$TARGET_USER"
  echo "Added to docker group. Please log out and back in, or run: newgrp docker"
fi

# Always ensure the service file is up to date (Nix GC can invalidate store paths)
NEEDS_RELOAD=false
NEEDS_RESTART=false
if [ ! -f "$SYSTEM_SERVICE" ]; then
  echo "Installing Docker systemd service..."
  run_root "$TEE" "$SYSTEM_SERVICE" >/dev/null <"$DOCKER_SERVICE_FILE"
  run_root "$SYSTEMCTL" enable docker
  NEEDS_RELOAD=true
  NEEDS_RESTART=true
elif ! "$DIFF" -q "$DOCKER_SERVICE_FILE" "$SYSTEM_SERVICE" >/dev/null 2>&1; then
  echo "Updating Docker systemd service (Nix store paths changed)..."
  run_root "$TEE" "$SYSTEM_SERVICE" >/dev/null <"$DOCKER_SERVICE_FILE"
  NEEDS_RELOAD=true
  NEEDS_RESTART=true
fi

if [ ! -d "$DOCKER_CONFIG_DIR" ]; then
  echo "Creating Docker daemon config directory..."
  run_root "$MKDIR" -p "$DOCKER_CONFIG_DIR"
fi

if [ ! -f "$DOCKER_DAEMON_CONFIG" ]; then
  echo "Installing Docker daemon config..."
  run_root "$INSTALL" -m 0644 "$DOCKER_DAEMON_FILE" "$DOCKER_DAEMON_CONFIG"
  NEEDS_RESTART=true
elif ! "$DIFF" -q "$DOCKER_DAEMON_FILE" "$DOCKER_DAEMON_CONFIG" >/dev/null 2>&1; then
  echo "Updating Docker daemon config..."
  run_root "$INSTALL" -m 0644 "$DOCKER_DAEMON_FILE" "$DOCKER_DAEMON_CONFIG"
  NEEDS_RESTART=true
fi

if [ "$NEEDS_RELOAD" = true ]; then
  run_root "$SYSTEMCTL" daemon-reload
fi

# Ensure inotify limits are high enough for Docker containers (e.g. cliproxyapi file watchers)
DESIRED_INOTIFY_INSTANCES=1024
CURRENT_INOTIFY_INSTANCES=$(cat /proc/sys/fs/inotify/max_user_instances 2>/dev/null || echo 0)
CURRENT_USERNS_INSTANCES=$(cat /proc/sys/user/max_inotify_instances 2>/dev/null || echo 0)
if [ "$CURRENT_INOTIFY_INSTANCES" -lt "$DESIRED_INOTIFY_INSTANCES" ]; then
  echo "Increasing fs.inotify.max_user_instances to $DESIRED_INOTIFY_INSTANCES..."
  echo "$DESIRED_INOTIFY_INSTANCES" | run_root "$TEE" /proc/sys/fs/inotify/max_user_instances >/dev/null
fi
if [ "$CURRENT_USERNS_INSTANCES" -lt "$DESIRED_INOTIFY_INSTANCES" ]; then
  echo "Increasing user.max_inotify_instances to $DESIRED_INOTIFY_INSTANCES..."
  echo "$DESIRED_INOTIFY_INSTANCES" | run_root "$TEE" /proc/sys/user/max_inotify_instances >/dev/null
fi
# Persist sysctl across reboots
SYSCTL_CONTENT="fs.inotify.max_user_instances = $DESIRED_INOTIFY_INSTANCES"
if [ ! -f "$SYSCTL_CONF" ] || ! "$GREP" -qF "$SYSCTL_CONTENT" "$SYSCTL_CONF" 2>/dev/null; then
  echo "Persisting inotify sysctl settings..."
  printf '%s\n%s\n' "$SYSCTL_CONTENT" "user.max_inotify_instances = $DESIRED_INOTIFY_INSTANCES" | run_root "$TEE" "$SYSCTL_CONF" >/dev/null
fi

# Start or restart Docker as needed
if ! "$SYSTEMCTL" is-active --quiet docker 2>/dev/null; then
  echo "Starting Docker daemon..."
  run_root "$SYSTEMCTL" start docker
  echo "Docker daemon started"
elif [ "$NEEDS_RESTART" = true ]; then
  echo "Restarting Docker daemon (configuration updated)..."
  # live-restore is reloadable, so a reload first lets a newly enabled
  # live-restore keep containers running through this restart.
  run_root "$SYSTEMCTL" reload docker || true
  run_root "$SYSTEMCTL" restart docker
  echo "Docker daemon restarted"
else
  echo "Docker daemon is already running"
fi
