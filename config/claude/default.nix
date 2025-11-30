{ config, ... }:
{
  home.file.".claude/settings.json" = {
    source = config.lib.file.mkOutOfStoreSymlink ./settings.json;
  };

  home.file.".claude/settings.local.json" = {
    source = config.lib.file.mkOutOfStoreSymlink ./settings.local.json;
  };

  home.file.".claude/pushover.sh" = {
    source = config.lib.file.mkOutOfStoreSymlink ./pushover.sh;
    executable = true;
  };
}
