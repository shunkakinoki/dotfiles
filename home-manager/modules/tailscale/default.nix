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

  # Check if user-level services should be enabled
  # Only enable if serviceConfig is explicitly set (not for system-level service only)
  configEnabled = cfg.serviceConfig != { } && cfg.serviceConfig != null;

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
        default = "${config.home.homeDirectory}/.local/run/tailscale/tailscaled.sock";
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
      type = types.str;
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
    home.file.".local/share/tailscale/tailscaled.state" = {
      source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.local/state/tailscale/tailscaled.state";
      force = true;
    };

    # Tailscaled service
    systemd.user.services.tailscaled = mkIf configEnabled {
      Unit = {
        Description = "Tailscale VPN daemon";
        After = [ "network-online.target" ];
        Wants = [ "network-online.target" ];
      };

      Service = {
        ExecStart = "${pkgs.tailscale}/bin/tailscaled --state=${config.xdg.dataHome}/tailscale/tailscaled.state --socket=${cfg.tailscaled.socketPath}";
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

      Service =
        let
          authKeyArg =
            if cfg.authKey != "" then
              "--authkey=${cfg.authKey}"
            else if cfg.authKeyFile != "" then
              "--authkey-file=${cfg.authKeyFile}"
            else
              "";

          upArgs =
            lib.filter (x: x != "") [
              authKeyArg
              (optionalString cfg.acceptRoutes "--accept-routes")
              (optionalString cfg.advertiseExitNode "--advertise-exit-node")
              (optionalString (cfg.useExitNode != "") "--exit-node=${cfg.useExitNode}")
            ]
            ++ cfg.extraUpArgs;

          upCommand = "${pkgs.tailscale}/bin/tailscale up ${concatStringsSep " " upArgs}";
        in
        {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = upCommand;
          ExecStop = "${pkgs.tailscale}/bin/tailscale down";
        };

      Install.WantedBy = [ "default.target" ];
    };

    home.activation.createTailscaleDirs = config.lib.dag.entryAfter [ "writeBoundary" ] ''
      $DRY_RUN_CMD ${pkgs.bash}/bin/bash "${./activate-create-dirs.sh}" \
        "${config.xdg.dataHome}/tailscale" \
        "$(dirname "${cfg.tailscaled.socketPath}")"
    '';

    # Install system-level tailscaled service (requires sudo)
    # Uses nix-generated service file for full declarative config
    home.activation.installTailscaleService = mkIf cfg.installSystemService (
      config.lib.dag.entryAfter [ "writeBoundary" ] ''
        $DRY_RUN_CMD ${pkgs.bash}/bin/bash "${./activate-install-service.sh}" \
          "${tailscaledServiceFile}" \
          "${config.home.homeDirectory}"
      ''
    );
  };
}
