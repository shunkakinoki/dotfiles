{ config, ... }:
{
  home.file.".factory/config.json" = {
    source = config.lib.file.mkOutOfStoreSymlink ./config.json;
    force = true;
  };
}
