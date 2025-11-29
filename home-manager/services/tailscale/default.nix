{
  config,
  pkgs,
  lib,
  ...
}:
with lib;
{
  home.activation.tailscaleStateDir = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    mkdir -p $HOME/.local/share/tailscale
    chmod 755 $HOME/.local/share/tailscale
  '';
}
// lib.mkIf pkgs.stdenv.isDarwin {
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

          # Configure Tailscale with basic connectivity
          ${pkgs.tailscale}/bin/tailscale up
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
// lib.mkIf pkgs.stdenv.isLinux {
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
      ExecStart = "${pkgs.bash}/bin/bash -c 'tailscale up'";
      ExecStop = "${pkgs.tailscale}/bin/tailscale down";
    };

    Install = {
      WantedBy = [ "default.target" ];
    };
  };
}
