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
    diff = "${pkgs.diffutils}/bin/diff";
    systemctl = "${pkgs.systemd}/bin/systemctl";
  };
  serviceFile = "${homeDir}/.config/k3s/k3s.service";
in
lib.mkIf (pkgs.stdenv.isLinux && host.isKyber) {
  home.activation.setupK3s = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    ${pkgs.bash}/bin/bash "${setupScript}" \
      "${serviceFile}" \
      "${homeDir}/.kube"
  '';
}
