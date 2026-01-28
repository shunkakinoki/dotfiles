{ config, ... }:
{
  xdg.configFile."jj/config.toml" = {
    source = ./config.toml;
  };
}
