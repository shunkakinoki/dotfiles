{ config, pkgs, lib, ... }:
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
      default = [];
      description = "Extra arguments to pass to tailscale up.";
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [ pkgs.tailscale ];

    # Create directory for Tailscale state
    system.activationScripts.postActivation.text = ''
      mkdir -p /var/lib/tailscale
      chmod 755 /var/lib/tailscale
    '';

    # System-level launchd service for tailscaled
    launchd.daemons.tailscaled = {
      script = ''
        ${pkgs.tailscale}/bin/tailscaled --state=/var/lib/tailscale/tailscaled.state --socket=/var/run/tailscale/tailscaled.sock
      '';
      serviceConfig = {
        KeepAlive = true;
        RunAtLoad = true;
        StandardOutPath = "/var/log/tailscaled.log";
        StandardErrorPath = "/var/log/tailscaled.error.log";
        UserName = "root";
        GroupName = "wheel";
        WorkingDirectory = "/var/lib/tailscale";
      };
    };

    # User-level launchd service for tailscale up
    launchd.agents.tailscale-up = {
      enable = true;
      script = ''
        # Wait for tailscaled to be ready
        for i in {1..30}; do
          if ${pkgs.tailscale}/bin/tailscale status >/dev/null 2>&1; then
            break
          fi
          sleep 1
        done
        
        # Configure Tailscale with specified options
        ${pkgs.tailscale}/bin/tailscale up \
          ${optionalString cfg.acceptRoutes "--accept-routes"} \
          ${optionalString cfg.advertiseExitNode "--advertise-exit-node"} \
          ${optionalString (cfg.useExitNode != "") "--exit-node=${cfg.useExitNode}"} \
          ${concatStringsSep " " cfg.extraUpArgs}
      '';
      serviceConfig = {
        RunAtLoad = true;
        KeepAlive = {
          SuccessfulExit = false;
        };
        StandardOutPath = "/tmp/tailscale-up.log";
        StandardErrorPath = "/tmp/tailscale-up.error.log";
      };
    };
  };
}