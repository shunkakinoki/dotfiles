{
  lib,
  isRunner,
  ...
}:
let
  # macOS default kern.tty.ptmx_max is 511. Electron apps (Claude, Cursor,
  # VS Code) leak PTYs over long sessions; once the cap is hit, new
  # terminals fail with `posix_openpt: Device not configured` (ENXIO).
  ptmxMax = 4096;
in
lib.mkIf (!isRunner) {
  launchd.daemons."com.shunkakinoki.sysctl-ptmx" = {
    script = ''
      /usr/sbin/sysctl -w kern.tty.ptmx_max=${toString ptmxMax}
    '';
    serviceConfig = {
      RunAtLoad = true;
      KeepAlive = false;
    };
  };
}
