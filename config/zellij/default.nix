{ config, ... }:
{
  xdg.configFile."zellij/config.kdl" = {
    source = ./config.kdl;
  };
  xdg.configFile."zellij/layouts/primary.kdl" = {
    source = ./layouts/primary.kdl;
  };
}
