{ config, pkgs, ... }:
let
  inherit (pkgs) lib;

  # Script to ensure user is in docker group and system docker is running
  setupDockerScript = pkgs.writeShellScript "setup-docker" ''
    set -euo pipefail

    # Check if docker group exists and user is in it
    if ! groups | grep -q docker; then
      echo "Adding user to docker group..."
      sudo usermod -aG docker $USER
      echo "✅ Added to docker group. Please log out and back in, or run: newgrp docker"
    fi

    # Check if system docker service exists and is running
    if ! systemctl is-active --quiet docker 2>/dev/null; then
      echo "Starting Docker daemon..."
      if [ ! -f /etc/systemd/system/docker.service ]; then
        echo "Installing Docker systemd service..."
        sudo tee /etc/systemd/system/docker.service > /dev/null << 'EOF'
[Unit]
Description=Docker Application Container Engine
Documentation=https://docs.docker.com
After=network-online.target
Wants=network-online.target

[Service]
Type=notify
ExecStart=${pkgs.docker}/bin/dockerd
ExecReload=/bin/kill -s HUP $MAINPID
Restart=always
RestartSec=10s

[Install]
WantedBy=multi-user.target
EOF
        sudo systemctl daemon-reload
        sudo systemctl enable docker
      fi
      sudo systemctl start docker
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
      if ! systemctl is-active --quiet docker 2>/dev/null; then
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
