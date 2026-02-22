{ config, lib, ... }:
{
  # Use activation script for settings.json instead of symlink
  # git-ai install-hooks needs write access, which breaks with Nix store symlinks
  home.activation.claudeConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD mkdir -p ~/.claude
    $DRY_RUN_CMD cp -f ${./settings.json} ~/.claude/settings.json
    $DRY_RUN_CMD chmod 644 ~/.claude/settings.json
  '';

  home.file.".claude/pushover.sh" = {
    source = ./pushover.sh;
    executable = true;
    force = true;
  };

  home.file.".claude/notify.sh" = {
    source = ./notify.sh;
    executable = true;
    force = true;
  };

  home.file.".claude/security.sh" = {
    source = ./security.sh;
    executable = true;
    force = true;
  };

  home.file.".claude/statusline-git.sh" = {
    source = ./statusline-git.sh;
    executable = true;
    force = true;
  };

  home.file.".claude/hooks/rtk-rewrite.sh" = {
    source = ./rtk-rewrite.sh;
    executable = true;
    force = true;
  };

  home.file.".claude/RTK.md" = {
    source = ./RTK.md;
    force = true;
  };
}
