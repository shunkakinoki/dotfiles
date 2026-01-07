{ config, ... }:
{
  home.file.".claude/settings.json" = {
    source = ./settings.json;
  };

  home.file.".claude/pushover.sh" = {
    source = ./pushover.sh;
    executable = true;
  };

  home.file.".claude/notify.sh" = {
    source = ./notify.sh;
    executable = true;
  };

  home.file.".claude/security.sh" = {
    source = ./security.sh;
    executable = true;
  };

  home.file.".claude/statusline-git.sh" = {
    source = ./statusline-git.sh;
    executable = true;
  };

  # Custom plugin marketplaces (Claude Code will merge with built-in ones)
  home.file.".claude/plugins/known_marketplaces.json" = {
    source = ./known_marketplaces.json;
  };
}
