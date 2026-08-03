{
  config,
  lib,
  pkgs,
  ...
}:
{
  # Copilot CLI mutates config.json, so copy the managed file into place.
  home.activation.copilotConfig = config.lib.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD ${pkgs.bash}/bin/bash "${./activate.sh}" "${./config.json}"
  '';
}
