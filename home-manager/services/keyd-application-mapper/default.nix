{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services."keyd-application-mapper";
in
{
  options.services."keyd-application-mapper" = {
    enable = lib.mkEnableOption "keyd application mapper user service";
  };

  config = lib.mkIf (pkgs.stdenv.isLinux && cfg.enable) {
    assertions = [
      {
        assertion = config.xdg.configFile ? "keyd/app.conf";
        message = "services.keyd-application-mapper requires xdg.configFile.\"keyd/app.conf\"";
      }
    ];

    systemd.user.services.keyd-application-mapper = {
      Unit = {
        Description = "keyd application mapper";
        After = [ "graphical-session.target" ];
        PartOf = [ "graphical-session.target" ];
      };
      Service = {
        Type = "simple";
        # Force a unit restart on switch when app.conf changes.
        Environment = [
          "KEYD_APP_CONF_HASH=${builtins.hashFile "sha256" config.xdg.configFile."keyd/app.conf".source}"
        ];
        # User managers can start before refreshed supplementary groups
        # are visible in the login session. Enter the keyd group
        # explicitly so the mapper can always reach /var/run/keyd.socket.
        ExecStart = "${pkgs.bash}/bin/bash -lc 'exec /run/wrappers/bin/sg keyd -c \"KEYD_BIN=${pkgs.keyd}/bin/keyd ${pkgs.keyd}/bin/keyd-application-mapper\"'";
        Restart = "on-failure";
        RestartSec = 3;
      };
      Install = {
        WantedBy = [ "graphical-session.target" ];
      };
    };
  };
}
