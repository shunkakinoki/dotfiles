{ config, ... }:
{
  home.file.".config/crush/crush.json" = {
    source = config.lib.file.mkOutOfStoreSymlink ./crush.json;
  };
}
