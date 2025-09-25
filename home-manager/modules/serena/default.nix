{ config, ... }:
{
  home.file.".serena/serena_config.yml" = {
    source = config.lib.file.mkOutOfStoreSymlink ./serena_config.yml;
  };
}
