{ config, ... }:
{
  home.file.".config/aichat/config.yaml" = {
    source = ./config.yaml;
    force = true;
  };
}
