{
  config,
  lib,
  pkgs,
  ...
}:
let
  serenaConfigDest = "${config.home.homeDirectory}/.serena/serena_config.yml";
in
{
  home.activation.serenaConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD ${pkgs.bash}/bin/bash "${./activate.sh}" "${./serena_config.yml}" "${serenaConfigDest}"
  '';
}
