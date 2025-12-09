# Tailscale configuration
{
  config,
  lib,
  pkgs,
  ...
}:
with lib;
let
  cfg = config.modules.tailscale;

  # Check if configuration is enabled
  configEnabled = (cfg.serviceConfig != { } && cfg.serviceConfig != null);

  # System service unit file (for non-NixOS Linux)
  tailscaledServiceFile = pkgs.writeText "tailscaled.service" ''
    [Unit]
    Description=Tailscale node agent
    Documentation=https://tailscale.com/kb/
    Wants=network-pre.target
    After=network-pre.target NetworkManager.service systemd-resolved.service

    [Service]
    ExecStartPre=${cfg.tailscaled.package}/bin/tailscaled --cleanup
    ExecStart=${cfg.tailscaled.package}/bin/tailscaled --state=/var/lib/tailscale/tailscaled.state --socket=/run/tailscale/tailscaled.sock --port ${toString cfg.port}
    ExecStopPost=${cfg.tailscaled.package}/bin/tailscaled --cleanup
    Restart=on-failure
    RuntimeDirectory=tailscale
    RuntimeDirectoryMode=0755
    StateDirectory=tailscale
    StateDirectoryMode=0700
    CacheDirectory=tailscale
    CacheDirectoryMode=0750
    Type=notify

    [Install]
    WantedBy=multi-user.target
  '';
in
{
  options.modules.tailscale = {
    enable = mkEnableOption "Tailscale VPN service";

    # Tailscale daemon configuration
    tailscaled = {
      package = mkOption {
        type = types.package;
        default = pkgs.tailscale;
        description = "Tailscale package to use";
      };

      stateDir = mkOption {
        type = types.str;
        default = "${config.xdg.dataHome}/tailscale";
        description = "Directory for Tailscale state files";
      };

      socketPath = mkOption {
        type = types.str;
        default = "${config.xdg.runtimeDir}/tailscale/tailscaled.sock";
        description = "Socket path for Tailscale daemon";
      };
    };

    # Optional auth key
    authKey = mkOption {
      type = types.str;
      default = "";
      description = "Tailscale auth key (use agenix for secrets)";
    };

    # Optional auth key file (better for secrets)
    authKeyFile = mkOption {
      type = types.path;
      default = "";
      description = "Path to file containing Tailscale auth key (better for secrets)";
    };

    # Tailscale up options
    acceptRoutes = mkOption {
      type = types.bool;
      default = false;
      description = "Accept routes from other nodes";
    };

    advertiseExitNode = mkOption {
      type = types.bool;
      default = false;
      description = "Advertise as exit node";
    };

    useExitNode = mkOption {
      type = types.str;
      default = "";
      description = "Use specific node as exit node";
    };

    extraUpArgs = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "Additional arguments to pass to tailscale up";
    };

    port = mkOption {
      type = types.int;
      default = 41641;
      description = "UDP port for Tailscale traffic";
    };

    installSystemService = mkOption {
      type = types.bool;
      default = true;
      description = "Install system-level tailscaled service (requires sudo, for non-NixOS Linux)";
    };

    # Important directories and files
    directories = mkOption {
      type = types.attrsOf types.anything;
      default = { };
      description = "Integration with home-manager's directories option";
    };

    files = mkOption {
      type = types.attrsOf types.anything;
      default = { };
      description = "Integration with home-manager's files option";
    };

    # Service module
    serviceConfig = mkOption {
      type = types.attrsOf types.anything;
      default = { };
      description = "Optional systemd service configuration override";
    };
  };

  config = mkIf cfg.enable {
    home.packages = [ cfg.tailscaled.package ];

    # Declare directories and files for home-manager
    home.file.".local/share/tailscale/tailscaled.state".source =
      config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.local/state/tailscale/tailscaled.state";

    # Tailscaled service
    systemd.user.services.tailscaled = mkIf configEnabled {
      Unit = {
        Description = "Tailscale VPN daemon";
        After = [ "network-online.target" ];
        Wants = [ "network-online.target" ];
      };

      Service = {
        ExecStart = "${pkgs.tailscale}/bin/tailscaled --state=${config.xdg.dataHome}/tailscale/tailscaled.state --socket=${config.xdg.runtimeDir}/tailscale/tailscaled.sock";
        Restart = "on-failure";
        RestartSec = 5;
      }
      // cfg.serviceConfig.service or { };

      Install.WantedBy = [ "default.target" ];
    };

    # Tailscale up service (runs once to connect)
    systemd.user.services.tailscale-up = mkIf configEnabled {
      Unit = {
        Description = "Connect Tailscale to network";
        After = [ "tailscaled.service" ];
        Requires = [ "tailscaled.service" ];
      };

      Service = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${pkgs.bash}/bin/bash -c '
          # Determine auth key
          AUTH_KEY=" "
          if [ -n \"${cfg.authKey}\" ]; then
            AUTH_KEY=\"${cfg.authKey}\"
          elif [ -n \"${cfg.authKeyFile}\" ] && [ -f \"${cfg.authKeyFile}\" ]; then
            AUTH_KEY=$(cat \"${cfg.authKeyFile}\")
          fi

          # Configure Tailscale with specified options
          tailscale up \
            ${
                      optionalString (cfg.authKey != "") "--authkey=${cfg.authKey}"
                    } \
            ${
                      optionalString (cfg.authKeyFile != "") "--authkey=$AUTH_KEY"
                    } \
            ${optionalString cfg.acceptRoutes "--accept-routes"} \
            ${optionalString cfg.advertiseExitNode "--advertise-exit-node"} \
            ${
                      optionalString (cfg.useExitNode != "") "--exit-node=${cfg.useExitNode}"
                    } \
            ${concatStringsSep " " cfg.extraUpArgs}'";
        ExecStop = "${pkgs.tailscale}/bin/tailscale down";
      };

      Install.WantedBy = [ "default.target" ];
    };

    home.activation.createTailscaleDirs = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      TAILSCALE_STATE_DIR="${config.xdg.dataHome}/tailscale"
      TAILSCALE_RUN_DIR="${config.xdg.runtimeDir}/tailscale"

      # Create directories
      $DRY_RUN_CMD mkdir -p "$TAILSCALE_STATE_DIR"
      $DRY_RUN_CMD mkdir -p "$TAILSCALE_RUN_DIR"

      # Set proper permissions
      $DRY_RUN_CMD chmod 700 "$TAILSCALE_STATE_DIR"
      $DRY_RUN_CMD chmod 700 "$TAILSCALE_RUN_DIR"
    '';

    # Install system-level tailscaled service (requires sudo)
    # Uses nix-generated service file for full declarative config
    home.activation.installTailscaleService = mkIf cfg.installSystemService (
      lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        SERVICE_FILE="/etc/systemd/system/tailscaled.service"
        NIX_SERVICE="${tailscaledServiceFile}"

        # Resolve an elevated command helper
        SUDO_CMD=""
        if command -v sudo >/dev/null 2>&1; then
          SUDO_CMD="sudo"
        elif command -v doas >/dev/null 2>&1; then
          SUDO_CMD="doas"
        elif [ "$(id -u)" -ne 0 ]; then
          echo "Tailscale system service installation requires root privileges, but sudo/doas is not available." >&2
          echo "Either install sudo, configure doas, or run home-manager as root." >&2
          exit 1
        fi

        run_root_cmd() {
          if [ -n "$SUDO_CMD" ]; then
            ${DRY_RUN_CMD:-} "$SUDO_CMD" "$@"
          else
            ${DRY_RUN_CMD:-} "$@"
          fi
        }

        # Only install if service file differs from nix-generated one
        if ! cmp -s "$NIX_SERVICE" "$SERVICE_FILE" 2>/dev/null; then
          echo "Installing tailscaled systemd service (requires root)..."
          run_root_cmd cp "$NIX_SERVICE" "$SERVICE_FILE"
          run_root_cmd systemctl daemon-reload
          run_root_cmd systemctl enable tailscaled
          echo "Tailscaled service installed. Run: sudo systemctl start tailscaled && tailscale up"
        fi
      ''
    );
  };
}
