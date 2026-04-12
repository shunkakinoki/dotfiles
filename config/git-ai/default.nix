{ pkgs, lib, ... }:
{
  home.activation.gitAiConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD ${pkgs.bash}/bin/bash ${./activate.sh} ${./config.json} ${pkgs.git}/bin/git
  '';
}
