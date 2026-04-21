{
  pkgs,
  username,
  ...
}:
{
  services.keyd.enable = true;

  # Optional: silence the setgid warning (nice to have, not required for functionality)
  users.groups.keyd = { };
  systemd.services.keyd.serviceConfig = {
    CapabilityBoundingSet = [ "CAP_SETGID" ];
    AmbientCapabilities = [ "CAP_SETGID" ];
  };

  # Restart keyd when config changes (on make switch)
  systemd.services.keyd.restartTriggers = [
    (builtins.hashFile "sha256" ./default.conf)
  ];

  environment.etc."keyd/default.conf".source = ./default.conf;

  home-manager.users.${username} = {
    xdg.configFile."keyd/app.conf".source = ./app.conf;

    systemd.user.services.keyd-application-mapper = {
      Unit = {
        Description = "keyd application mapper";
        After = [ "graphical-session.target" ];
        PartOf = [ "graphical-session.target" ];
      };
      Service = {
        Type = "simple";
        # Force a unit restart on switch when app.conf changes.
        Environment = [ "KEYD_APP_CONF_HASH=${builtins.hashFile "sha256" ./app.conf}" ];
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
