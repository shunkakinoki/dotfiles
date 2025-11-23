{ config, ... }:
{
  home.file.".config/nvim/init.lua" = {
    source = config.lib.file.mkOutOfStoreSymlink ./init.lua;
  };
  home.file.".config/nvim/nvim-pack-lock.json" = {
    source = config.lib.file.mkOutOfStoreSymlink ./nvim-pack-lock.json;
  };
}
