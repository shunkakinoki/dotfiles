{ config, ... }:
{
  home.file.".config/starship.toml" = {
    source = config.lib.file.mkOutOfStoreSymlink ./starship.toml;
    force = true;
  };
}
