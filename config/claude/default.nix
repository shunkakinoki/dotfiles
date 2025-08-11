{ config, ... }:
{
  home.file.".claude/settings.local.json" = {
    source = config.lib.file.mkOutOfStoreSymlink ./settings.local.json;
  };

  home.file.".cursor/settings.json" = {
    source = config.lib.file.mkOutOfStoreSymlink ./settings.json;
  };
}
