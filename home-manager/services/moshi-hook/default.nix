{ pkgs, ... }:
let
  inherit (pkgs) lib;
in
{
  launchd.agents.moshi-hook = lib.mkIf pkgs.stdenv.isDarwin {
    enable = true;
    config = {
      ProgramArguments = [
        "${pkgs.moshi-hook}/bin/moshi-hook"
        "serve"
      ];
      KeepAlive = true;
      RunAtLoad = true;
      StandardOutPath = "/tmp/moshi-hook.log";
      StandardErrorPath = "/tmp/moshi-hook.error.log";
    };
  };

  systemd.user.services.moshi-hook = lib.mkIf pkgs.stdenv.isLinux {
    Unit = {
      Description = "Moshi Hook daemon";
      After = [ "network.target" ];
    };
    Service = {
      Type = "simple";
      ExecStart = "${pkgs.moshi-hook}/bin/moshi-hook serve";
      Restart = "always";
      RestartSec = 5;
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
  };
}
