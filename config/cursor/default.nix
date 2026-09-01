{
  config,
  lib,
  pkgs,
  ...
}:
{
  # CAAM invokes Cursor by its canonical provider name. Headless Linux hosts
  # only install Cursor Agent, so expose it at that canonical path.
  home.file.".local/bin/cursor" = lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
    source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.local/bin/cursor-agent";
    force = true;
  };

  # Use activation script instead of symlink
  # git-ai install-hooks needs write access, which breaks with Nix store symlinks
  home.activation.cursorHooks = config.lib.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD ${pkgs.bash}/bin/bash "${./activate.sh}" "${../../generated/hooks/moshi/cursor/hooks.json}"
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
