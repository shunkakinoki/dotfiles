{ config, ... }:
{
  xdg.configFile."worktrunk/config.toml" = {
    source = ./config.toml;
    force = true;
  };
}
