{ config, lib, ... }:
{
  # Use activation script for settings.json instead of symlink
  # git-ai install-hooks needs write access, which breaks with Nix store symlinks
  home.activation.claudeConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD mkdir -p ~/.claude
    $DRY_RUN_CMD cp -f ${./settings.json} ~/.claude/settings.json
    $DRY_RUN_CMD chmod 644 ~/.claude/settings.json
  '';

  home.file.".claude/hooks/pushover.sh" = {
    source = ./hooks/pushover.sh;
    executable = true;
    force = true;
  };

  home.file.".claude/hooks/notify.sh" = {
    source = ./hooks/notify.sh;
    executable = true;
    force = true;
  };

  home.file.".claude/hooks/security.sh" = {
    source = ./hooks/security.sh;
    executable = true;
    force = true;
  };

  home.file.".claude/hooks/statusline.sh" = {
    source = ./hooks/statusline.sh;
    executable = true;
    force = true;
  };

  home.file.".claude/hooks/rtk-rewrite.sh" = {
    source = ./hooks/rtk-rewrite.sh;
    executable = true;
    force = true;
  };

  home.file.".claude/hooks/atuin-history.sh" = {
    source = ./hooks/atuin-history.sh;
    executable = true;
    force = true;
  };

  home.file.".claude/hooks/auto-switch.sh" = {
    source = ./hooks/auto-switch.sh;
    executable = true;
    force = true;
  };
}
