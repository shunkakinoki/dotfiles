{
  inputs,
  lib,
  pkgs,
  ...
}:
let
  inherit (inputs) host;
in
{
  home.activation.kube-config = lib.mkIf (pkgs.stdenv.isLinux && host.isKyber) (
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      $DRY_RUN_CMD ${pkgs.bash}/bin/bash "${./activate.sh}"
    ''
  );
}
