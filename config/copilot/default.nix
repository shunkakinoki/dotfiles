{ lib, pkgs, ... }:
{
  # Copilot CLI mutates config.json, so copy the managed file into place.
  home.activation.copilotConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD ${pkgs.bash}/bin/bash "${./activate.sh}" "${./config.json}"
  '';
}
