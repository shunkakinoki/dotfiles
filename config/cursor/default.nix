{ config, ... }:
{
  home.file.".cursor/hooks.json" = {
    source = ./hooks.json;
    force = true;
  };
}
