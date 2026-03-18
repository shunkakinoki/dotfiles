#!/usr/bin/env bash
# Ensures the user is in the docker group and the system Docker daemon is running.
# @shadow@, @gnugrep@, @systemd@, @coreutils@, @docker_service_file@
# are substituted by pkgs.replaceVars.
set -euo pipefail

# Define paths
GROUPS_CMD=@shadow@/bin/groups
GREP=@gnugrep@/bin/grep
USERMOD=@shadow@/bin/usermod
SYSTEMCTL=@systemd@/bin/systemctl
TEE=@coreutils@/bin/tee
DOCKER_SERVICE_FILE=@docker_service_file@

# Check if docker group exists and user is in it
if ! "$GROUPS_CMD" | "$GREP" -q docker; then
  echo "Adding user to docker group..."
  sudo "$USERMOD" -aG docker "$USER"
  echo "Added to docker group. Please log out and back in, or run: newgrp docker"
fi

# Check if system docker service exists and is running
if ! "$SYSTEMCTL" is-active --quiet docker 2>/dev/null; then
  echo "Starting Docker daemon..."
  if [ ! -f /etc/systemd/system/docker.service ]; then
    echo "Installing Docker systemd service..."
    # shellcheck disable=SC2024
    sudo "$TEE" /etc/systemd/system/docker.service >/dev/null <"$DOCKER_SERVICE_FILE"
    sudo "$SYSTEMCTL" daemon-reload
    sudo "$SYSTEMCTL" enable docker
  fi
  sudo "$SYSTEMCTL" start docker
  echo "Docker daemon started"
else
  echo "Docker daemon is already running"
fi
