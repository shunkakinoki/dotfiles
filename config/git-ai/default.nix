{
  config,
  pkgs,
  lib,
  ...
}:
{
  home.activation.gitAiConfig = config.lib.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD ${pkgs.bash}/bin/bash "${./activate.sh}" "${./config.json}" "${pkgs.git}/bin/git"
  '';
}
