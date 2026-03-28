{ inputs, pkgs, ... }:
let
  inherit (pkgs) lib;
  inherit (pkgs.stdenv) isDarwin;
  inherit (inputs.host) isMatic;
in
{
  # macOS: launchd agent for input-leap server
  launchd.agents.input-leap-server = lib.mkIf isDarwin {
    enable = true;
    config = {
      ProgramArguments = [
        "${pkgs.input-leap}/bin/input-leaps"
        "--no-daemon"
        "--config"
        "${../../../config/input-leap/server.conf}"
        "--address"
        ":24800"
        "--disable-crypto"
      ];
      KeepAlive = true;
      RunAtLoad = true;
      StandardOutPath = "/tmp/input-leap-server.log";
      StandardErrorPath = "/tmp/input-leap-server.error.log";
    };
  };

  # Only on matic (not kyber)
  systemd.user.services.input-leap-client = lib.mkIf isMatic {
    Unit = {
      Description = "Input Leap client (connects to galactica)";
      After = [
        "graphical-session.target"
        "network-online.target"
      ];
      Requires = [ "graphical-session.target" ];
    };
    Service = {
      Type = "simple";
      ExecStart = "${pkgs.input-leap}/bin/input-leapc --no-daemon --name matic --disable-crypto galactica:24800";
      Restart = "on-failure";
      RestartSec = 5;
    };
    Install = {
      WantedBy = [ "graphical-session.target" ];
    };
  };
}
