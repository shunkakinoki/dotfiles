{ pkgs, ... }:
let
  inherit (pkgs) lib;
in
{
  systemd.user.services.gas-town = lib.mkIf pkgs.stdenv.isLinux {
    Unit = {
      Description = "Gas Town daemon (dolt + tmux + worker orchestration)";
      After = [ "network.target" ];
    };
    Service = {
      Type = "simple";
      Environment = [
        "PATH=${
          lib.makeBinPath [
            pkgs.bash
            pkgs.coreutils
            pkgs.git
            pkgs.tmux
          ]
        }:$HOME/.local/bin:$HOME/go/bin:/usr/local/bin"
      ];
      ExecStart = "${pkgs.bash}/bin/bash ${./start.sh}";
      Restart = "always";
      RestartSec = 30;
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
  };
}
