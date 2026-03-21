#!/usr/bin/env bash
# Ensures the user is in the docker group and the system Docker daemon is running.
# @shadow@, @gnugrep@, @systemd@, @coreutils@, @docker_service_file@, @diffutils@
# are substituted by pkgs.replaceVars.
set -euo pipefail

# Define paths
GROUPS_CMD=@shadow@/bin/groups
GREP=@gnugrep@/bin/grep
USERMOD=@shadow@/bin/usermod
SYSTEMCTL=@systemd@/bin/systemctl
TEE=@coreutils@/bin/tee
DIFF=@diffutils@/bin/diff
DOCKER_SERVICE_FILE=@docker_service_file@
SYSTEM_SERVICE=/etc/systemd/system/docker.service

# Check if docker group exists and user is in it
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
