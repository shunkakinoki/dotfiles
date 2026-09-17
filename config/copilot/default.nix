{
  config,
  lib,
  pkgs,
  ...
}:
{
  home.activation.copilotConfig = config.lib.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD ${pkgs.bash}/bin/bash "${./activate.sh}" "${./hooks.json}"
  '';
}
