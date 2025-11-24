{ config, lib, ... }:
let
  nvimPackLockJson = ./nvim-pack-lock.json;
in
{
  home.file.".config/nvim/init.lua" = {
    source = config.lib.file.mkOutOfStoreSymlink ./init.lua;
    force = true;
  };
  # Copy nvim-pack-lock.json via activation script instead of symlinking
  # so Neovim can write to it. Home Manager always creates symlinks for
  # managed files, so we handle this file separately.
  home.activation.copyNvimPackLock = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD mkdir -p "$HOME/.config/nvim"
    $DRY_RUN_CMD cp -f ${nvimPackLockJson} "$HOME/.config/nvim/nvim-pack-lock.json"
    $DRY_RUN_CMD chmod 644 "$HOME/.config/nvim/nvim-pack-lock.json"
  '';
}
