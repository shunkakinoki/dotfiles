{ pkgs }:
{ config, lib, ... }:
let
  logDir = "${config.home.homeDirectory}/Library/Logs";
in
{
  # Photo Booth has no setting for where it saves captures, so they are copied
  # out of its library. Export latency does not matter here and every run
  # catches up on anything missed, so launchd WatchPaths is enough. The interval
  # retries movies that were still being written when the watch fired.
  launchd.agents.photo-booth-export = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
    enable = true;
    config = {
      ProgramArguments = [
        "${pkgs.bash}/bin/bash"
        "${./export.sh}"
      ];
      EnvironmentVariables.PATH = "/usr/bin:/bin";
      RunAtLoad = true;
      StartInterval = 60;
      WatchPaths = [ "${config.home.homeDirectory}/Pictures/Photo Booth Library/Pictures" ];
      StandardOutPath = "${logDir}/photo-booth-export.log";
      StandardErrorPath = "${logDir}/photo-booth-export.error.log";
    };
  };
}
