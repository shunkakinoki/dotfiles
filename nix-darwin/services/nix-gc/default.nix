{
  lib,
  isRunner,
  ...
}:
lib.mkIf (!isRunner) {
  launchd.daemons."com.shunkakinoki.nix-gc" = {
    script = ''
      /nix/var/nix/profiles/default/bin/nix-collect-garbage --delete-older-than 30d
    '';
    serviceConfig = {
      RunAtLoad = false;
      StartCalendarInterval = [
        {
          Weekday = 0;
          Hour = 3;
          Minute = 0;
        }
      ];
    };
  };
}
