{ config, ... }:
{
  home.file.".config/direnv/direnvrc" = {
    source = config.lib.file.mkOutOfStoreSymlink ./direnvrc;
  };
}
