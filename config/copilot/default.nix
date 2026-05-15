{ lib, pkgs, ... }:
{
  # Copilot CLI mutates config.json, so merge managed hooks into the live file.
  home.activation.copilotConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD ${pkgs.bash}/bin/bash "${./activate.sh}" "${./config.json}" "${pkgs.jq}/bin/jq"
  '';
}
