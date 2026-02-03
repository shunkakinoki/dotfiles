{ config, lib, ... }:
{
  # Use activation script instead of home.file symlink
  # Codex CLI uses atomic writes that break symlinks, so we force-copy on each switch
  home.activation.codexConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD mkdir -p ~/.codex
    $DRY_RUN_CMD cp -f ${./config.toml} ~/.codex/config.toml
    $DRY_RUN_CMD chmod 600 ~/.codex/config.toml
  '';
}
