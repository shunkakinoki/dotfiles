{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  inherit (inputs) host;
  serviceFile = "${config.home.homeDirectory}/.config/k3s/k3s.service";
in
lib.mkIf (pkgs.stdenv.isLinux && host.isKyber) {
  home.activation.setupK3s = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if ! ${pkgs.diffutils}/bin/diff -q "${serviceFile}" /etc/systemd/system/k3s.service >/dev/null 2>&1; then
      $DRY_RUN_CMD sudo cp "${serviceFile}" /etc/systemd/system/k3s.service
      $DRY_RUN_CMD sudo ${pkgs.systemd}/bin/systemctl daemon-reload
      $DRY_RUN_CMD sudo ${pkgs.systemd}/bin/systemctl enable --now k3s
    fi
  '';
}
