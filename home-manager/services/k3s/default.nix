{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  inherit (inputs) host;
  k3sServiceFile = config.modules.k3s.serviceFile;
in
lib.mkIf (pkgs.stdenv.isLinux && host.isKyber) {
  home.packages = [ pkgs.k3s ];

  home.activation.setupK3s = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if ! ${pkgs.diffutils}/bin/diff -q "${k3sServiceFile}" /etc/systemd/system/k3s.service >/dev/null 2>&1; then
      $DRY_RUN_CMD sudo cp "${k3sServiceFile}" /etc/systemd/system/k3s.service
      $DRY_RUN_CMD sudo ${pkgs.systemd}/bin/systemctl daemon-reload
      $DRY_RUN_CMD sudo ${pkgs.systemd}/bin/systemctl enable --now k3s
    fi
  '';
}
