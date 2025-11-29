{
  config,
  pkgs,
  lib,
  ...
}:
with lib;
let
  cfg = config.services.tailscale;
in
{
  options.services.tailscale = {
    enable = mkEnableOption "Tailscale VPN service";

    acceptRoutes = mkOption {
      type = types.bool;
      default = false;
      description = "Whether to accept advertised routes from the Tailscale network.";
    };

    advertiseExitNode = mkOption {
      type = types.bool;
      default = false;
      description = "Whether to advertise this node as an exit node.";
    };

    useExitNode = mkOption {
      type = types.str;
      default = "";
      description = "Exit node to use (leave empty to not use any exit node).";
    };

    extraUpArgs = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "Extra arguments to pass to tailscale up.";
    };
  };

  config = mkIf cfg.enable {
    home.packages = [ pkgs.tailscale ];

    # Create directory for Tailscale state
    home.activation.tailscaleStateDir = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      mkdir -p $HOME/.local/share/tailscale
      chmod 755 $HOME/.local/share/tailscale
    '';

    # User-level systemd service for tailscaled
    systemd.user.services.tailscaled = {
      Unit = {
        Description = "Tailscale client daemon";
        After = [ "network.target" ];
        PartOf = [ "graphical-session.target" ];
      };

      Service = {
        ExecStart = "${pkgs.tailscale}/bin/tailscaled --state=${config.xdg.dataHome}/tailscale/tailscaled.state --socket=${config.xdg.runtimeDir}/tailscale/tailscaled.sock";
        Restart = "on-failure";
        RestartSec = 5;
      };

      Install = {
        WantedBy = [ "default.target" ];
      };
    };

    # User-level systemd service for tailscale up
    systemd.user.services.tailscale-up = {
      Unit = {
        Description = "Configure Tailscale connection";
        After = [ "tailscaled.service" ];
        PartOf = [ "tailscaled.service" ];
      };

      Service = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${pkgs.bash}/bin/bash -c 'tailscale up ${optionalString cfg.acceptRoutes "--accept-routes"} ${optionalString cfg.advertiseExitNode "--advertise-exit-node"} ${
          optionalString (cfg.useExitNode != "") "--exit-node=${cfg.useExitNode}"
        } ${concatStringsSep " " cfg.extraUpArgs}'";
        ExecStop = "${pkgs.tailscale}/bin/tailscale down";
      };

      Install = {
        WantedBy = [ "default.target" ];
      };
    };
  };
}
