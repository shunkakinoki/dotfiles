{ pkgs, ... }:
let
  inherit (pkgs) lib;
in
{
  systemd.user.services.moshi-hook = lib.mkIf pkgs.stdenv.isLinux {
    Unit = {
      Description = "Moshi Hook daemon";
      After = [ "network.target" ];
    };
    Service = {
      Type = "simple";
      ExecStart = "%h/.local/bin/moshi-hook serve";
      Restart = "always";
      RestartSec = 5;
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
  };
}
