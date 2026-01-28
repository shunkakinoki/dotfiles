{ config, ... }:
{
  home.file.".factory/config.json" = {
    source = ./config.json;
    force = true;
  };
}
