{ config, ... }:
{
  home.file.".serena/serena_config.template.yml" = {
    source = config.lib.file.mkOutOfStoreSymlink ./serena_config.template.yml;
  };
}
