{ pkgs, ... }:
{
  launchd.agents.cliproxyapi = pkgs.lib.mkIf pkgs.stdenv.isDarwin {
    enable = true;
    config = {
      ProgramArguments = [
        "${pkgs.bash}/bin/bash"
        "${./start.sh}"
      ];
      Environment = {
        PATH = "${pkgs.lib.makeBinPath [ pkgs.gnused ]}:/opt/homebrew/bin:/usr/local/bin";
      };
      KeepAlive = true;
      RunAtLoad = true;
      StandardOutPath = "/tmp/cliproxyapi.log";
      StandardErrorPath = "/tmp/cliproxyapi.error.log";
    };
  };
}
