{ config, ... }:
{
  home.file.".claude/settings.local.json" = {
    source = config.lib.file.mkOutOfStoreSymlink ./settings.local.json;
  };
}
