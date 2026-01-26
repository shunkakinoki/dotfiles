{ config, ... }:
{
  xdg.configFile."zellij/config.kdl" = {
    source = config.lib.file.mkOutOfStoreSymlink ./config.kdl;
  };
  xdg.configFile."zellij/layouts/primary.kdl" = {
    source = config.lib.file.mkOutOfStoreSymlink ./layouts/primary.kdl;
  };
}
