{
  pkgs,
  lib,
  config,
  ...
}:

with lib;

let
  cfg = config.programs.droid;

  # Install script that uses the official Factory AI CLI installer
  installScript = pkgs.writeShellScriptBin "install-droid" ''
    set -euo pipefail

    INSTALL_DIR="$HOME/.local/bin"

    mkdir -p "$INSTALL_DIR"

    echo "Installing droid CLI from Factory AI..."
    cd "$(${pkgs.coreutils}/bin/mktemp -d)"

    # Download and execute the official installer with curl in PATH
    ${pkgs.curl}/bin/curl -fsSL https://app.factory.ai/cli > installer.sh

    # Export PATH to include necessary tools for the installer
    export PATH="${pkgs.curl}/bin:${pkgs.coreutils}/bin:${pkgs.gnused}/bin:${pkgs.gnutar}/bin:${pkgs.gzip}/bin:$PATH"

    ${pkgs.bash}/bin/bash installer.sh

    # Verify installation
    if [ -f "''${INSTALL_DIR}/droid" ]; then
      echo "✅ droid installed successfully to ''${INSTALL_DIR}/droid"
      echo "Version: $(''${INSTALL_DIR}/droid --version 2>&1 || echo 'installed')"
    else
      echo "⚠️ droid installation completed but binary not found at expected location"
    fi
  '';

  droidWrapper = pkgs.writeShellScriptBin "droid" ''
    INSTALL_DIR="$HOME/.local/bin"
    DROID_BIN="''${INSTALL_DIR}/droid"

    # Install droid if not present
    if [ ! -f "''${DROID_BIN}" ]; then
      echo "droid not found. Installing latest version..."
      ${installScript}/bin/install-droid
    fi

    # Execute droid with all arguments
    exec "''${DROID_BIN}" "$@"
  '';
in
{
  options.programs.droid = {
    enable = mkEnableOption "droid - Factory AI CLI for AI-powered development";

    package = mkOption {
      type = types.package;
      default = droidWrapper;
      description = "The droid wrapper package";
    };
  };

  config = mkIf cfg.enable {
    home.packages = [
      cfg.package
      installScript
    ];

    # Install droid on activation
    home.activation.installDroid = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      if [ ! -f "$HOME/.local/bin/droid" ]; then
        $DRY_RUN_CMD ${installScript}/bin/install-droid || echo "⚠️ Failed to install droid. You can install it later by running: install-droid"
      fi
    '';
  };
}
