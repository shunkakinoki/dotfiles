{ lib, ... }:
{
  # Use activation script instead of home.file symlink
  # Codex CLI uses atomic writes that break symlinks, so we force-copy on each switch
  home.activation.codexConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD mkdir -p ~/.codex/hooks
    $DRY_RUN_CMD cp -f ${./config.toml} ~/.codex/config.toml
    $DRY_RUN_CMD chmod 600 ~/.codex/config.toml
    $DRY_RUN_CMD cp -f ${./hooks.json} ~/.codex/hooks.json
    $DRY_RUN_CMD chmod 644 ~/.codex/hooks.json
  '';

  home.file.".codex/hooks/notify.sh" = {
    source = ./hooks/notify.sh;
    executable = true;
    force = true;
  };

  home.file.".codex/hooks/pushover.sh" = {
    source = ./hooks/pushover.sh;
    executable = true;
    force = true;
  };

  home.file.".codex/hooks/security.sh" = {
    source = ./hooks/security.sh;
    executable = true;
    force = true;
  };

  home.file.".codex/hooks/rtk-rewrite.sh" = {
    source = ./hooks/rtk-rewrite.sh;
    executable = true;
    force = true;
  };

  home.file.".codex/hooks/atuin-history.sh" = {
    source = ./hooks/atuin-history.sh;
    executable = true;
    force = true;
  };
}
