{ pkgs, ... }:
let
  inherit (pkgs) lib;
in
{
  launchd.agents.screenshot-clipboard = lib.mkIf pkgs.stdenv.isDarwin {
    enable = true;
    config = {
      ProgramArguments = [
        "${pkgs.bash}/bin/bash"
        "${./watch.sh}"
      ];
      EnvironmentVariables = {
        PATH = "${
          lib.makeBinPath [
            pkgs.fswatch
          ]
        }:/usr/bin:/bin";
      };
      RunAtLoad = true;
      KeepAlive = true;
      ProcessType = "Background";
      StandardOutPath = "/tmp/screenshot-clipboard.log";
      StandardErrorPath = "/tmp/screenshot-clipboard.error.log";
    };
  };
}
