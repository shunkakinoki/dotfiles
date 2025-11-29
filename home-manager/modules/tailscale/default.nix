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
    home.packages = [ pkgs.tailscale ];

    # Create directory for Tailscale state
    home.activation.tailscaleStateDir = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      mkdir -p $HOME/.local/share/tailscale
      chmod 755 $HOME/.local/share/tailscale
    '';
  };
}
// lib.mkIf (pkgs.stdenv.isDarwin && config.services.tailscale.enable) {
  # macOS launchd service for tailscaled
  launchd.agents.tailscaled = {
    enable = true;
    config = {
      ProgramArguments = [
        "${pkgs.tailscale}/bin/tailscaled"
        "--state=$HOME/.local/share/tailscale/tailscaled.state"
        "--socket=$HOME/.local/share/tailscale/tailscaled.sock"
      ];
      KeepAlive = true;
      RunAtLoad = true;
      StandardOutPath = "$HOME/.local/share/tailscale/tailscaled.log";
      StandardErrorPath = "$HOME/.local/share/tailscale/tailscaled.error.log";
    };
  };

  # macOS launchd service for tailscale up
  launchd.agents.tailscale-up = {
    enable = true;
    config = {
      ProgramArguments = [
        "${pkgs.bash}/bin/bash"
        "-c"
        ''
          # Wait for tailscaled to be ready
          for i in {1..30}; do
            if ${pkgs.tailscale}/bin/tailscale status >/dev/null 2>&1; then
              break
            fi
            sleep 1
          done

          # Configure Tailscale with specified options
          ${pkgs.tailscale}/bin/tailscale up \
            ${optionalString config.services.tailscale.acceptRoutes "--accept-routes"} \
            ${optionalString config.services.tailscale.advertiseExitNode "--advertise-exit-node"} \
            ${optionalString (config.services.tailscale.useExitNode != "") "--exit-node=${config.services.tailscale.useExitNode}"} \
            ${concatStringsSep " " config.services.tailscale.extraUpArgs}
        ''
      ];
      RunAtLoad = true;
      KeepAlive = {
        SuccessfulExit = false;
      };
      StandardOutPath = "$HOME/.local/share/tailscale/tailscale-up.log";
      StandardErrorPath = "$HOME/.local/share/tailscale/tailscale-up.error.log";
    };
  };
}
// lib.mkIf (pkgs.stdenv.isLinux && config.services.tailscale.enable) {
  # Linux systemd service for tailscaled
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

  # Linux systemd service for tailscale up
  systemd.user.services.tailscale-up = {
    Unit = {
      Description = "Configure Tailscale connection";
      After = [ "tailscaled.service" ];
      PartOf = [ "tailscaled.service" ];
    };

    Service = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${pkgs.bash}/bin/bash -c 'tailscale up \
        ${optionalString config.services.tailscale.acceptRoutes "--accept-routes"} \
        ${optionalString config.services.tailscale.advertiseExitNode "--advertise-exit-node"} \
        ${optionalString (config.services.tailscale.useExitNode != "") "--exit-node=${config.services.tailscale.useExitNode}"} \
        ${concatStringsSep " " config.services.tailscale.extraUpArgs}'";
      ExecStop = "${pkgs.tailscale}/bin/tailscale down";
    };

    Install = {
      WantedBy = [ "default.target" ];
    };
  };
}
