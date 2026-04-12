{
  config,
  inputs,
  pkgs,
  lib,
  ...
}:
let
  inherit (inputs.host) isKyber isGalactica;
  enabled = isKyber || isGalactica;
in
{
  home.activation.obsidianConfig = lib.mkIf enabled (
    config.lib.dag.entryAfter [ "writeBoundary" ] ''
      $DRY_RUN_CMD ${pkgs.bash}/bin/bash ${./activate.sh} \
        ${./obsidian.json} \
        ${config.home.homeDirectory} \
        ${pkgs.gnused}/bin/sed
    ''
  );
}
