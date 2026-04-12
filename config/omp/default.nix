{ lib, pkgs, ... }:
{
  # Use activation script instead of home.file symlink.
  # Keep only the tracked config.yml in dotfiles and leave runtime state untouched.
  home.activation.ompConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD ${pkgs.bash}/bin/bash "${./activate.sh}" "${./config.yml}"
  '';
}
