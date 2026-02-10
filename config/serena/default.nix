{ config, ... }:
{
  home.file.".serena/serena_config.yml" = {
    text = builtins.readFile ./serena_config.yml;
    force = true;
  };
}
