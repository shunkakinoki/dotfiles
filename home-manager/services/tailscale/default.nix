{ config, pkgs, lib, ... }:
with lib;
{
  home.packages = [ pkgs.tailscale ];

  # Create directory for Tailscale state
  home.activation.tailscaleStateDir = lib.hm.dag.entryAfter ["writeBoundary"] ''
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
      ExecStart = "${pkgs.bash}/bin/bash -c 'tailscale up'";
      ExecStop = "${pkgs.tailscale}/bin/tailscale down";
    };

    Install = {
      WantedBy = [ "default.target" ];
    };
  };
}