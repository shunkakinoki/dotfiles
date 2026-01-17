{ config, ... }:
{
  home.file.".claude/settings.json" = {
    source = ./settings.json;
    force = true;
  };

  home.file.".claude/pushover.sh" = {
    source = ./pushover.sh;
    executable = true;
    force = true;
  };

  home.file.".claude/notify.sh" = {
    source = ./notify.sh;
    executable = true;
    force = true;
  };

  home.file.".claude/security.sh" = {
    source = ./security.sh;
    executable = true;
    force = true;
  };

  home.file.".claude/statusline-git.sh" = {
    source = ./statusline-git.sh;
    executable = true;
    force = true;
  };
}
