{ ... }:
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
}
