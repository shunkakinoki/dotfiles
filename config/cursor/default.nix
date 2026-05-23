{ lib, pkgs, ... }:
{
  # Use activation script instead of symlink
  # git-ai install-hooks needs write access, which breaks with Nix store symlinks
  home.activation.cursorHooks = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD ${pkgs.bash}/bin/bash "${./activate.sh}" "${./hooks.json}"
  '';

  home.file.".cursor/hooks/with-env.sh" = {
    source = ./hooks/with-env.sh;
    executable = true;
    force = true;
  };

  home.file.".cursor/hooks/security.sh" = {
    source = ./hooks/security.sh;
    executable = true;
    force = true;
  };

  home.file.".cursor/hooks/notify.sh" = {
    source = ./hooks/notify.sh;
    executable = true;
    force = true;
  };

  home.file.".cursor/hooks/pushover.sh" = {
    source = ./hooks/pushover.sh;
    executable = true;
    force = true;
  };
}
