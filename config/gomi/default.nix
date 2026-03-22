{ config, ... }:
{
  xdg.configFile."gomi/config.yaml" = {
    source = ./config.yaml;
  };
}
