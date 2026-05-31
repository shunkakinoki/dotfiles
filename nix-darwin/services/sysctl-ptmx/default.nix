{
  lib,
  isRunner,
  ...
}:
let
  # macOS default kern.tty.ptmx_max is 511. Electron apps (Claude, Cursor,
  # VS Code) leak PTYs over long sessions; once the cap is hit, new
  # terminals fail with `posix_openpt: Device not configured` (ENXIO).
  #
  # The XNU kernel rejects values above its hard ceiling with EINVAL
  # (observed: 4096 rejected, 999 accepted). 999 is the historical XNU
  # upper bound and the highest reliably-settable value across recent
  # macOS releases. Errors are swallowed so a future kernel that tightens
  # the bound further does not break activation.
  ptmxMax = 999;
in
lib.mkIf (!isRunner) {
  launchd.daemons."com.shunkakinoki.sysctl-ptmx" = {
    script = ''
      /usr/sbin/sysctl -w kern.tty.ptmx_max=${toString ptmxMax} || true
    '';
    serviceConfig = {
      RunAtLoad = true;
      KeepAlive = false;
    };
  };
}
