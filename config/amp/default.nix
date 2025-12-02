{ config, ... }:
{
  xdg.configFile."amp/settings.json" = {
    source = config.lib.file.mkOutOfStoreSymlink ./settings.json;
  };
}
