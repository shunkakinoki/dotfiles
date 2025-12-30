{ config, ... }:
{
  xdg.configFile."jj/config.toml" = {
    source = config.lib.file.mkOutOfStoreSymlink ./config.toml;
  };
}
