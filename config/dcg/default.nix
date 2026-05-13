{ lib, pkgs, ... }:
{
  home.activation.dcgConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD ${pkgs.bash}/bin/bash "${./activate.sh}" "${./config.toml}"
  '';
}
