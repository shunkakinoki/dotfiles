{ config, pkgs, ... }:
let
  inherit (pkgs) lib;

  # Systemd service file for Docker daemon
  dockerServiceFile = pkgs.writeText "docker.service" ''
    [Unit]
    Description=Docker Application Container Engine
    Documentation=https://docs.docker.com
    After=network-online.target
    Wants=network-online.target

    [Service]
    Type=notify
    ExecStart=${pkgs.docker}/bin/dockerd
    ExecReload=${pkgs.coreutils}/bin/kill -s HUP $MAINPID
    Restart=always
    RestartSec=10s

    [Install]
    WantedBy=multi-user.target
  '';

  # Script to ensure user is in docker group and system docker is running
  setupDockerScript = pkgs.writeShellScript "setup-docker" ''
    set -euo pipefail

    # Define paths
    GROUPS=${pkgs.shadow}/bin/groups
    GREP=${pkgs.gnugrep}/bin/grep
    USERMOD=${pkgs.shadow}/bin/usermod
    SYSTEMCTL=${pkgs.systemd}/bin/systemctl
    TEE=${pkgs.coreutils}/bin/tee
    DOCKER_SERVICE_FILE=${dockerServiceFile}

    # Check if docker group exists and user is in it
    if ! $GROUPS | $GREP -q docker; then
      echo "Adding user to docker group..."
      sudo $USERMOD -aG docker $USER
      echo "✅ Added to docker group. Please log out and back in, or run: newgrp docker"
    fi

    # Check if system docker service exists and is running
    if ! $SYSTEMCTL is-active --quiet docker 2>/dev/null; then
      echo "Starting Docker daemon..."
      if [ ! -f /etc/systemd/system/docker.service ]; then
        echo "Installing Docker systemd service..."
        sudo $TEE /etc/systemd/system/docker.service > /dev/null < "$DOCKER_SERVICE_FILE"
        sudo $SYSTEMCTL daemon-reload
        sudo $SYSTEMCTL enable docker
      fi
      sudo $SYSTEMCTL start docker
      echo "✅ Docker daemon started"
    else
      echo "✅ Docker daemon is already running"
    fi
  '';
in
{
  # Provide setup script for system Docker
  home.packages = lib.mkIf pkgs.stdenv.isLinux [
    (pkgs.writeShellScriptBin "docker-setup" ''
      exec ${setupDockerScript}
    '')
  ];

  # Check docker availability on activation
  home.activation.checkDocker = lib.mkIf pkgs.stdenv.isLinux (
    config.lib.dag.entryAfter [ "writeBoundary" ] ''
      if ! ${pkgs.systemd}/bin/systemctl is-active --quiet docker 2>/dev/null; then
        if [ -t 0 ]; then
          echo ""
          echo "⚠️  Docker daemon is not running."
          echo "   Run 'docker-setup' to configure system Docker."
          echo ""
        fi
      fi
    ''
  );
}
