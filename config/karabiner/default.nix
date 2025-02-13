{ config, ... }:
{
  home.file.".config/karabiner/karabiner.json" = {
    source = config.lib.file.mkOutOfStoreSymlink ./karabiner.json;
  };
}
