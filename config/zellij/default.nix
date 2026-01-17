{ config, ... }:
{
  xdg.configFile."zellij/config.kdl" = {
    source = config.lib.file.mkOutOfStoreSymlink ./config.kdl;
  };
}
