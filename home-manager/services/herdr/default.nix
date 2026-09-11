{
  config,
  lib,
  pkgs,
  ...
}:
let
  homeDir = config.home.homeDirectory;
in
{
  launchd.agents.herdr-server = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
    enable = true;
    config = {
      ProgramArguments = [
        "${pkgs.bash}/bin/bash"
        "${./start.sh}"
        "${pkgs.herdr}/bin/herdr"
      ];
      WorkingDirectory = homeDir;
      RunAtLoad = true;
      KeepAlive = true;
      ThrottleInterval = 10;
      EnvironmentVariables = {
        HOME = homeDir;
        PATH = "${homeDir}/.local/bin:${homeDir}/.bun/bin:/etc/profiles/per-user/${config.home.username}/bin:${homeDir}/.nix-profile/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin";
      };
      StandardOutPath = "${homeDir}/.config/herdr/herdr-launchd.log";
      StandardErrorPath = "${homeDir}/.config/herdr/herdr-launchd.error.log";
    };
  };
}
