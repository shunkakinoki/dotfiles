{ config, ... }:
{
  home.file.".serena/serena_config.yml" = {
    source = ./serena_config.yml;
    force = true;
  };
}
