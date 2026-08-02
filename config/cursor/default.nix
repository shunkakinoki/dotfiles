{ lib, pkgs, ... }:
let
  hooks = pkgs.replaceVars ./hooks.json {
    moshiHook = "${pkgs.moshi-hook}/bin/moshi-hook";
  };
in
{
  # Use activation script instead of symlink
  # git-ai install-hooks needs write access, which breaks with Nix store symlinks
  home.activation.cursorHooks = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD ${pkgs.bash}/bin/bash "${./activate.sh}" "${hooks}"
  '';

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
