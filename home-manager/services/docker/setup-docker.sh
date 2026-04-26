#!/usr/bin/env bash
# Ensures the user is in the docker group and the system Docker daemon is running.
# @shadow@, @gnugrep@, @systemd@, @coreutils@, @docker_service_file@, @diffutils@
# are substituted by pkgs.replaceVars.
set -euo pipefail

# Define paths
GROUPS_CMD=@coreutils@/bin/groups
GROUPADD=@shadow@/bin/groupadd
GREP=@gnugrep@/bin/grep
USERMOD=@shadow@/bin/usermod
SYSTEMCTL=@systemd@/bin/systemctl
TEE=@coreutils@/bin/tee
DIFF=@diffutils@/bin/diff
DOCKER_SERVICE_FILE=@docker_service_file@
SYSTEM_SERVICE=/etc/systemd/system/docker.service

# Ensure docker group exists
if ! getent group docker >/dev/null 2>&1; then
  echo "Creating docker group..."
  sudo "$GROUPADD" docker
fi

# Check if user is in docker group
if ! "$GROUPS_CMD" | "$GREP" -q docker; then
  echo "Adding user to docker group..."
  sudo "$USERMOD" -aG docker "$USER"
  echo "Added to docker group. Please log out and back in, or run: newgrp docker"
fi

# Always ensure the service file is up to date (Nix GC can invalidate store paths)
NEEDS_RELOAD=false
if [ ! -f "$SYSTEM_SERVICE" ]; then
  echo "Installing Docker systemd service..."
  # shellcheck disable=SC2024
  sudo "$TEE" "$SYSTEM_SERVICE" >/dev/null <"$DOCKER_SERVICE_FILE"
  sudo "$SYSTEMCTL" enable docker
  NEEDS_RELOAD=true
elif ! "$DIFF" -q "$DOCKER_SERVICE_FILE" "$SYSTEM_SERVICE" >/dev/null 2>&1; then
  echo "Updating Docker systemd service (Nix store paths changed)..."
  # shellcheck disable=SC2024
  sudo "$TEE" "$SYSTEM_SERVICE" >/dev/null <"$DOCKER_SERVICE_FILE"
  NEEDS_RELOAD=true
fi

if [ "$NEEDS_RELOAD" = true ]; then
  sudo "$SYSTEMCTL" daemon-reload
fi

# Ensure inotify limits are high enough for Docker containers (e.g. cliproxyapi file watchers)
DESIRED_INOTIFY_INSTANCES=1024
CURRENT_INOTIFY_INSTANCES=$(cat /proc/sys/fs/inotify/max_user_instances 2>/dev/null || echo 0)
CURRENT_USERNS_INSTANCES=$(cat /proc/sys/user/max_inotify_instances 2>/dev/null || echo 0)
if [ "$CURRENT_INOTIFY_INSTANCES" -lt "$DESIRED_INOTIFY_INSTANCES" ]; then
  echo "Increasing fs.inotify.max_user_instances to $DESIRED_INOTIFY_INSTANCES..."
  echo "$DESIRED_INOTIFY_INSTANCES" | sudo "$TEE" /proc/sys/fs/inotify/max_user_instances >/dev/null
fi
if [ "$CURRENT_USERNS_INSTANCES" -lt "$DESIRED_INOTIFY_INSTANCES" ]; then
  echo "Increasing user.max_inotify_instances to $DESIRED_INOTIFY_INSTANCES..."
  echo "$DESIRED_INOTIFY_INSTANCES" | sudo "$TEE" /proc/sys/user/max_inotify_instances >/dev/null
fi
# Persist sysctl across reboots
SYSCTL_CONF="/etc/sysctl.d/99-docker-inotify.conf"
SYSCTL_CONTENT="fs.inotify.max_user_instances = $DESIRED_INOTIFY_INSTANCES"
if [ ! -f "$SYSCTL_CONF" ] || ! "$GREP" -qF "$SYSCTL_CONTENT" "$SYSCTL_CONF" 2>/dev/null; then
  echo "Persisting inotify sysctl settings..."
  printf '%s\n%s\n' "$SYSCTL_CONTENT" "user.max_inotify_instances = $DESIRED_INOTIFY_INSTANCES" | sudo "$TEE" "$SYSCTL_CONF" >/dev/null
fi

# Start or restart Docker as needed
if ! "$SYSTEMCTL" is-active --quiet docker 2>/dev/null; then
  echo "Starting Docker daemon..."
  sudo "$SYSTEMCTL" start docker
  echo "Docker daemon started"
elif [ "$NEEDS_RELOAD" = true ]; then
  echo "Restarting Docker daemon (service file updated)..."
  sudo "$SYSTEMCTL" restart docker
  echo "Docker daemon restarted"
else
  echo "Docker daemon is already running"
fi
