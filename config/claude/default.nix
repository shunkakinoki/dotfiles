{ config, ... }:
{
  home.file.".claude/settings.json" = {
    source = config.lib.file.mkOutOfStoreSymlink ./settings.json;
  };

  home.file.".claude/settings.local.json" = {
    source = config.lib.file.mkOutOfStoreSymlink ./settings.local.json;
  };
}
