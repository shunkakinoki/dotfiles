{ config, ... }:
{
  home.file.".config/nvim/init.lua" = {
    source = config.lib.file.mkOutOfStoreSymlink ./init.lua;
    force = true;
  };
  # Copy nvim-pack-lock.json instead of symlinking so Neovim can write to it
  # Use make neovim-sync to sync changes back to the repo
  home.file.".config/nvim/nvim-pack-lock.json" = {
    source = ./nvim-pack-lock.json;
    force = true;
  };
}
