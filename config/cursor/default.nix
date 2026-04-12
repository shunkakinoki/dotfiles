{ lib, pkgs, ... }:
{
  # Use activation script instead of symlink
  # git-ai install-hooks needs write access, which breaks with Nix store symlinks
  home.activation.cursorHooks = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD ${pkgs.bash}/bin/bash ${./activate.sh} ${./hooks.json}
  '';
}
