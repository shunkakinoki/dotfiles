{ config, ... }:
{
  home.file.".config/starship.toml" = {
    source = ./starship.toml;
    force = true;
  };
}
