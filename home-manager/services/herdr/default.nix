{
  config,
  lib,
  pkgs,
  ...
}:
let
  homeDir = config.home.homeDirectory;
  herdrBin = "${pkgs.llm-agents.herdr}/bin/herdr";
in
{
  launchd.agents.herdr-server = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
    enable = true;
    config = {
      ProgramArguments = [
        "${pkgs.bash}/bin/bash"
        "${./start.sh}"
        herdrBin
      ];
      WorkingDirectory = homeDir;
      RunAtLoad = true;
      KeepAlive = true;
      ThrottleInterval = 10;
      EnvironmentVariables = {
        HOME = homeDir;
        HERDR_BIN_PATH = herdrBin;
        PATH = "${homeDir}/.local/bin:${homeDir}/.bun/bin:/etc/profiles/per-user/${config.home.username}/bin:${homeDir}/.nix-profile/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin";
      };
      StandardOutPath = "${homeDir}/.config/herdr/herdr-launchd.log";
      StandardErrorPath = "${homeDir}/.config/herdr/herdr-launchd.error.log";
    };
  };
}
