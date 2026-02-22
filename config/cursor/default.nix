{ config, lib, ... }:
{
  # Use activation script instead of symlink
  # git-ai install-hooks needs write access, which breaks with Nix store symlinks
  home.activation.cursorHooks = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD mkdir -p ~/.cursor
    $DRY_RUN_CMD cp -f ${./hooks.json} ~/.cursor/hooks.json
    $DRY_RUN_CMD chmod 644 ~/.cursor/hooks.json
  '';
}
