{ config, ... }:
{
  home.file.".config/karabiner/karabiner.json" = {
    source = ./karabiner.json;
    force = true;
  };
}
