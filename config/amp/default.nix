{ config, ... }:
{
  xdg.configFile."amp/settings.json" = {
    source = ./settings.json;
  };
}
