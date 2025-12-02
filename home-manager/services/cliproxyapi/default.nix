{ pkgs }:
let
  inherit (pkgs) lib writeShellApplication;

  cliproxyapiHomebrew = writeShellApplication {
    name = "cliproxyapi-homebrew";
    text = ''
      set -euo pipefail

      if [ -x /opt/homebrew/bin/cliproxyapi ]; then
        exec /opt/homebrew/bin/cliproxyapi "$@"
      elif [ -x /usr/local/bin/cliproxyapi ]; then
        exec /usr/local/bin/cliproxyapi "$@"
      else
        echo "cliproxyapi binary not found; install it with \"brew install cliproxyapi\"" >&2
        exit 1
      fi
    '';
  };
in
lib.mkIf pkgs.stdenv.isDarwin {
  launchd.agents.cliproxyapi = {
    enable = true;
    config = {
      ProgramArguments = [
        (lib.getExe cliproxyapiHomebrew)
      ];
      KeepAlive = true;
      RunAtLoad = true;
      StandardOutPath = "/tmp/cliproxyapi.log";
      StandardErrorPath = "/tmp/cliproxyapi.error.log";
    };
  };
}
