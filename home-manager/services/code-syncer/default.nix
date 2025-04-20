{ pkgs, ... }:
{
  launchd.agents.code-syncer = pkgs.lib.mkIf pkgs.stdenv.isDarwin {
    enable = true;
    config = {
      ProgramArguments = [
        "${pkgs.bash}/bin/bash"
        "${./sync.sh}"
      ];
      Environment = {
        PATH = "${pkgs.lib.makeBinPath [
          pkgs.fswatch
        ]}";
      };
      RunAtLoad = true;
      KeepAlive = true;
      StandardOutPath = "/tmp/code-syncer.log";
      StandardErrorPath = "/tmp/code-syncer.error.log";
    };
  };
}
