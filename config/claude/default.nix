{ config, ... }:
{
  home.file.".claude/settings.json" = {
    source = ./settings.json;
  };

  home.file.".claude/settings.local.json" = {
    source = ./settings.local.json;
  };

  home.file.".claude/pushover.sh" = {
    source = ./pushover.sh;
    executable = true;
  };
}
