{ pkgs, ... }:
{
  launchd.agents.brew-upgrader = pkgs.lib.mkIf pkgs.stdenv.isDarwin {
    enable = true;
    config = {
      ProgramArguments = [
        "${pkgs.bash}/bin/bash"
        "${./upgrade.sh}"
      ];
      RunAtLoad = true;
      StartInterval = 10800;
      StandardOutPath = "/tmp/brew-upgrader.log";
      StandardErrorPath = "/tmp/brew-upgrader.error.log";
    };
  };
}
