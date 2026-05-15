{ lib, pkgs, ... }:
{
  # Copilot CLI mutates config.json, so copy the managed file into place.
  home.activation.copilotConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD ${pkgs.bash}/bin/bash "${./activate.sh}" "${./config.json}"
  '';

  home.file.".copilot/hooks/rtk-rewrite.sh" = {
    source = ../codex/hooks/rtk-rewrite.sh;
    executable = true;
    force = true;
  };

  home.file.".copilot/hooks/security.sh" = {
    source = ../codex/hooks/security.sh;
    executable = true;
    force = true;
  };
}
