{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  inherit (inputs) host;
  homeDir = config.home.homeDirectory;
  setupScript = pkgs.replaceVars ./activate.sh {
    awk = "${pkgs.gawk}/bin/awk";
    blkid = "${pkgs.util-linux}/bin/blkid";
    diff = "${pkgs.diffutils}/bin/diff";
    find = "${pkgs.findutils}/bin/find";
    findmnt = "${pkgs.util-linux}/bin/findmnt";
    systemctl = "${pkgs.systemd}/bin/systemctl";
    tune2fs = "${pkgs.e2fsprogs}/bin/tune2fs";
  };
  serviceFile = "${homeDir}/.config/k3s/k3s.service";
  mountFile = "${homeDir}/.config/k3s/var-lib-rancher-k3s-agent-containerd.mount";
  journaldFile = "${homeDir}/.config/k3s/journald.conf.d/10-kyber-limits.conf";
  healthServiceFile = "${homeDir}/.config/k3s/kyber-host-health.service";
  healthTimerFile = "${homeDir}/.config/k3s/kyber-host-health.timer";
  smartdServiceFile = "${homeDir}/.config/k3s/kyber-smartd.service";
in
lib.mkIf (pkgs.stdenv.isLinux && host.isKyber) {
  home.activation.setupK3s = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    ${pkgs.bash}/bin/bash "${setupScript}" \
      "${serviceFile}" \
      "${homeDir}/.kube" \
      "${mountFile}" \
      "${journaldFile}" \
      "${healthServiceFile}" \
      "${healthTimerFile}" \
      "${smartdServiceFile}"
  '';
}
